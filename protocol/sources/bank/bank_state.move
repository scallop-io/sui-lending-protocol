module protocol::bank_state {
  
  use std::vector;
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use std::type_name::{Self, TypeName};
  use x::ac_table::AcTable;
  use x::wit_table::{Self, WitTable};
  use math::exponential::{Self, Exp, exp};
  use protocol::bank::{Self, Bank, BankCoin};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  
  struct BalanceSheet has store {
    cash: u128,
    debt: u128,
    reserve: u128,
  }
  
  struct BorrowIndex has store {
    mark: Exp,
    interestRate: Exp,
    lastUpdated: u64,
  }
  
  struct BankState has store {
    balanceSheet: BalanceSheet,
    borrowIndex: BorrowIndex,
  }
  
  struct BankStates has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<BankStates, TypeName, BankState> {
    wit_table::new<BankStates, TypeName, BankState>(
      BankStates{},
      true,
      ctx
    )
  }
  
  public fun handle_borrow<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    let typeName = type_name::get<T>();
    accrue_all_interests(self, interestModels, now);
    update_balance_sheet_for_borrow(self, typeName, borrowAmount);
    update_interest_rates(self, interestModels);
    bank::withdraw_underlying_coin(bank, borrowAmount)
  }
  
  public fun handle_repay<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    balance: Balance<T>,
    now: u64,
  ) {
    let typeName = type_name::get<T>();
    let repayAmount = balance::value(&balance);
    accrue_all_interests(self, interestModels, now);
    update_balance_sheet_for_repay(self, typeName, repayAmount);
    update_interest_rates(self, interestModels);
    bank::deposit_underlying_coin(bank, balance)
  }
  
  public fun handle_redeem<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    bankCoinBalance: Balance<BankCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, interestModels, now);
    let reddemBalance = redeem(self, bank, bankCoinBalance);
    update_interest_rates(self, interestModels);
    reddemBalance
  }
  
  public fun handle_mint<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    balance: Balance<T>,
    now: u64,
  ): Balance<BankCoin<T>> {
    accrue_all_interests(self, interestModels, now);
    let mintBalance = mint(self, bank, balance);
    update_interest_rates(self, interestModels);
    mintBalance
  }
  
  public fun compound_interests(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    now: u64,
  ) {
    accrue_all_interests(self, interestModels, now);
    update_interest_rates(self, interestModels);
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun borrow_mark(
    self: &WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName
  ): Exp {
    let stat = wit_table::borrow(self, typeName);
    stat.borrowIndex.mark
  }
  
  // update bank balance sheet for repay
  fun update_balance_sheet_for_repay(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    stat.balanceSheet.debt = stat.balanceSheet.debt - (repayAmount as u128);
    stat.balanceSheet.cash = stat.balanceSheet.cash + (repayAmount as u128);
  }
  
  // update bank balance sheet for borrow
  fun update_balance_sheet_for_borrow(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName,
    borrowAmount: u64
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    stat.balanceSheet.debt = stat.balanceSheet.debt + (borrowAmount as u128);
    stat.balanceSheet.cash = stat.balanceSheet.cash - (borrowAmount as u128);
  }
  
  // accure interest for all banks
  fun accrue_all_interests(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    now: u64
  ) {
    let assetTypes = wit_table::keys(self);
      let (i, n) = (0, vector::length(&assetTypes));
      while (i < n) {
        let type = *vector::borrow(&assetTypes, i);
        let stat = wit_table::borrow_mut(BankStates{}, self, type);
        accrue_interest(stat, interestModels, type, now);
        i = i + 1;
      };
  }
  
  // accure interest for all banks
  fun update_interest_rates(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
  ) {
    let assetTypes = wit_table::keys(self);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let stat = wit_table::borrow_mut(BankStates{}, self, type);
      update_interest_rate(stat, interestModels, type);
      i = i + 1;
    };
  }
  
  fun accrue_interest(
    stat: &mut BankState,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
    now: u64,
  ) {
    /*********
    timeDelta = now - lastUpdated
    *********/
    let timeDelta = ((now - stat.borrowIndex.lastUpdated) as u128);
    
    /*********
    increaseFactor = 1 + timeDelta * interestRate
    *********/
    let increaseFactor = exponential::add_exp(
      exp(1, 1),
      exponential::mul_scalar_exp(stat.borrowIndex.interestRate, timeDelta)
    );
    
    /*********
    newDebt = oldDebt * increaseFactor
    *********/
    let oldDebt =stat.balanceSheet.debt;
    stat.balanceSheet.debt = exponential::mul_scalar_exp_truncate(
      stat.balanceSheet.debt,
      increaseFactor
    );
    
    /*********
    newMark = oldMark * increaseFactor
    *********/
    stat.borrowIndex.mark = exponential::mul_exp(stat.borrowIndex.mark, increaseFactor);
    
    /*******
     newReserve = reserve + reserveFactor * (newDebt - oldDebt)
    ********/
    let reserveFactor = interest_model::reserve_factor(interestModels, typeName);
    stat.balanceSheet.reserve = stat.balanceSheet.reserve + exponential::mul_scalar_exp_truncate(
      (stat.balanceSheet.debt - oldDebt),
      reserveFactor
    );
    
    // set lastUpdated to now
    stat.borrowIndex.lastUpdated = now
  }
  
  fun update_interest_rate(
    stat: &mut BankState,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
  ) {
    /*******
    update interest with the new bank ulti rate
    ultiRate = debt / (debt + cash - reserve)
    ********/
    let ultiRate = exponential::exp(
      stat.balanceSheet.debt,
      stat.balanceSheet.debt + stat.balanceSheet.cash - stat.balanceSheet.reserve
    );
    let interestRate = interest_model::calc_interest(interestModels, typeName, ultiRate);
    stat.borrowIndex.interestRate = interestRate;
  }
  
  fun redeem<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    bankCoinBalance: Balance<BankCoin<T>>
  ): Balance<T> {
    let typeName = type_name::get<T>();
    let bankCoinAmount = balance::value(&bankCoinBalance);
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    /**********
      redeemRate = (cash + debt - reserve) / totalBankCoinSupply
      redeemAmount = bankCoinAmount * redeemRate
    **********/
    let redeemRate = exponential::exp(
      stat.balanceSheet.cash + stat.balanceSheet.debt - stat.balanceSheet.reserve,
      (bank::bank_coin_total_supply(bank) as u128),
    );
    let redeemAmount = exponential::mul_scalar_exp_truncate(
      (bankCoinAmount as u128),
      redeemRate
    );
    // update the bank balance sheet
    stat.balanceSheet.cash = stat.balanceSheet.cash - redeemAmount;
    // burn the bank coin, and return the underyling coin
    bank::burn_bank_coin(bank, bankCoinBalance);
    bank::withdraw_underlying_coin(bank, (redeemAmount as u64))
  }
  
  fun mint<T>(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    bank: &mut Bank<T>,
    balance: Balance<T>
  ): Balance<BankCoin<T>> {
    let typeName = type_name::get<T>();
    let coinAmount = (balance::value(&balance) as u128);
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    /**********
      mintRate = totalBankSupply / (cash + debt - reserve)
      mintAmount = coinAmount * mintRate
    **********/
    let mintRate = exponential::exp(
      (bank::bank_coin_total_supply(bank) as u128),
      stat.balanceSheet.cash + stat.balanceSheet.debt - stat.balanceSheet.reserve,
    );
    let mintAmount = exponential::mul_scalar_exp_truncate(
      coinAmount,
      mintRate
    );
    // update the bank balance sheet
    stat.balanceSheet.cash = stat.balanceSheet.cash + coinAmount;
    // put the underyling coin, and mint the bank coin
    bank::deposit_underlying_coin(bank, balance);
    bank::issue_bank_coin(bank, (mintAmount as u64))
  }
  
  fun bank_coin_mint_amount<T>(
    self: &WitTable<BankStates, TypeName, BankState>,
    bank: &Bank<T>,
  ): Exp {
    let typeName = type_name::get<T>();
    let stat = wit_table::borrow(self, typeName);
    /**********
      bankCoinRedeemRate = totalBankCoinSupply / (cash + debt - reserve)
    **********/
    exponential::exp(
      (bank::bank_coin_total_supply(bank) as u128),
      stat.balanceSheet.cash + stat.balanceSheet.debt - stat.balanceSheet.reserve,
    )
  }
}
