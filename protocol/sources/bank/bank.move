module protocol::bank {
  
  use std::vector;
  use std::type_name::{Self, TypeName};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::wit_table::{Self, WitTable};
  use x::ownership::Ownership;
  use math::exponential::{Self, Exp, exp};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::bank_vault::{Self, BankVault, BankCoin};
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has store {
    cash: u128,
    debt: u128,
    reserve: u128,
  }
  
  struct BorrowIndexes has drop {}
  
  struct BorrowIndex has store {
    mark: Exp,
    interestRate: Exp,
    lastUpdated: u64,
  }
  
  struct Bank has key {
    id: UID,
    balanceSheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
    borrowIndexes: WitTable<BorrowIndexes, TypeName, BorrowIndex>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    vault: BankVault
  }
  
  public fun new(ctx: &mut TxContext)
  : (Bank, Ownership<AcTableOwnership>, Ownership<AcTableOwnership>)
  {
    let (interestModels, interestModelsOwnership) = interest_model::new(ctx);
    let (riskModels, riskModelsOwnership) = risk_model::new(ctx);
    let bank = Bank {
      id: object::new(ctx),
      balanceSheets: wit_table::new(BalanceSheets{}, true, ctx),
      borrowIndexes: wit_table::new(BorrowIndexes{}, false, ctx),
      interestModels,
      riskModels,
      vault: bank_vault::new(ctx),
    };
    (bank, interestModelsOwnership, riskModelsOwnership)
  }
  
  public fun handle_borrow<T>(
    self: &mut Bank,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    let typeName = type_name::get<T>();
    accrue_all_interests(self, now);
    update_balance_sheet_for_borrow(self, typeName, borrowAmount);
    update_interest_rates(self);
    bank_vault::withdraw_underlying_coin(&mut self.vault, borrowAmount)
  }
  
  public fun handle_repay<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ) {
    let typeName = type_name::get<T>();
    let repayAmount = balance::value(&balance);
    accrue_all_interests(self, now);
    update_balance_sheet_for_repay(self, typeName, repayAmount);
    update_interest_rates(self);
    bank_vault::deposit_underlying_coin(&mut self.vault, balance)
  }
  
  public fun handle_redeem<T>(
    self: &mut Bank,
    bankCoinBalance: Balance<BankCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = redeem(self, bankCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public fun handle_mint<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ): Balance<BankCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = mint(self, balance);
    update_interest_rates(self);
    mintBalance
  }
  
  public fun compound_interests(
    self: &mut Bank,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }
  
  public fun borrow_mark(self: &Bank, typeName: TypeName): Exp {
    let borrowIndex = wit_table::borrow(&self.borrowIndexes, typeName);
    borrowIndex.mark
  }
  
  public fun collateral_factor(self: &Bank, typeName: TypeName): Exp {
    risk_model::collateral_factor(&self.riskModels, typeName)
  }
  
  // update bank balance sheet for repay
  fun update_balance_sheet_for_repay(
    self: &mut Bank,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt - (repayAmount as u128);
    balanceSheet.cash = balanceSheet.cash + (repayAmount as u128);
  }
  
  // update bank balance sheet for borrow
  fun update_balance_sheet_for_borrow(
    self: &mut Bank,
    typeName: TypeName,
    borrowAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt + (borrowAmount as u128);
    balanceSheet.cash = balanceSheet.cash - (borrowAmount as u128);
  }
  
  // accure interest for all banks
  fun accrue_all_interests(self: &mut Bank, now: u64) {
    let assetTypes = wit_table::keys(&self.balanceSheets);
      let (i, n) = (0, vector::length(&assetTypes));
      while (i < n) {
        let type = *vector::borrow(&assetTypes, i);
        let balanceSheet = wit_table::borrow_mut(BalanceSheets {}, &mut self.balanceSheets, type);
        let borrowIndex = wit_table::borrow_mut(BorrowIndexes {}, &mut self.borrowIndexes, type);
        let interestModel = ac_table::borrow(&self.interestModels, type);
        accrue_interest(balanceSheet, borrowIndex, interestModel, now);
        i = i + 1;
      };
  }
  
  // accure interest for all banks
  fun update_interest_rates(
    self: &mut Bank,
  ) {
    let assetTypes = wit_table::keys(&self.balanceSheets);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let balanceSheet = wit_table::borrow_mut(BalanceSheets {}, &mut self.balanceSheets, type);
      let borrowIndex = wit_table::borrow_mut(BorrowIndexes {}, &mut self.borrowIndexes, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      update_interest_rate(borrowIndex, balanceSheet, interestModel);
      i = i + 1;
    };
  }
  
  fun accrue_interest(
    balanceSheet: &mut BalanceSheet,
    borrowIndex: &mut BorrowIndex,
    interestModel: &InterestModel,
    now: u64
  ) {
    /*********
    timeDelta = now - lastUpdated
    *********/
    let timeDelta = ((now - borrowIndex.lastUpdated) as u128);
    
    /*********
    increaseFactor = 1 + timeDelta * interestRate
    *********/
    let increaseFactor = exponential::add_exp(
      exp(1, 1),
      exponential::mul_scalar_exp(borrowIndex.interestRate, timeDelta)
    );
    
    /*********
    newDebt = oldDebt * increaseFactor
    *********/
    let oldDebt = balanceSheet.debt;
    balanceSheet.debt = exponential::mul_scalar_exp_truncate(
      balanceSheet.debt,
      increaseFactor
    );
    
    /*********
    newMark = oldMark * increaseFactor
    *********/
    borrowIndex.mark = exponential::mul_exp(borrowIndex.mark, increaseFactor);
    
    /*******
     newReserve = reserve + reserveFactor * (newDebt - oldDebt)
    ********/
    let reserveFactor = interest_model::reserve_factor(interestModel);
    balanceSheet.reserve = balanceSheet.reserve + exponential::mul_scalar_exp_truncate(
      balanceSheet.debt - oldDebt,
      reserveFactor
    );
    
    // set lastUpdated to now
    borrowIndex.lastUpdated = now
  }
  
  fun update_interest_rate(
    borrowIndex: &mut BorrowIndex,
    balanceSheet: &BalanceSheet,
    interestModel: &InterestModel,
  ) {
    /*******
    update interest with the new bank ulti rate
    ultiRate = debt / (debt + cash - reserve)
    ********/
    let ultiRate = exponential::exp(
      balanceSheet.debt,
      balanceSheet.debt + balanceSheet.cash - balanceSheet.reserve
    );
    let interestRate = interest_model::calc_interest(interestModel, ultiRate);
    borrowIndex.interestRate = interestRate;
  }
  
  fun redeem<T>(
    self: &mut Bank,
    bankCoinBalance: Balance<BankCoin<T>>
  ): Balance<T> {
    let typeName = type_name::get<T>();
    let bankCoinAmount = balance::value(&bankCoinBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    /**********
      redeemRate = (cash + debt - reserve) / totalBankCoinSupply
      redeemAmount = bankCoinAmount * redeemRate
    **********/
    let redeemRate = exponential::exp(
      balanceSheet.cash + balanceSheet.debt - balanceSheet.reserve,
      (bank_vault::bank_coin_total_supply<T>(&self.vault) as u128),
    );
    let redeemAmount = exponential::mul_scalar_exp_truncate(
      (bankCoinAmount as u128),
      redeemRate
    );
    // update the bank balance sheet
    balanceSheet.cash = balanceSheet.cash - redeemAmount;
    // burn the bank coin, and return the underyling coin
    bank_vault::burn_bank_coin(&mut self.vault, bankCoinBalance);
    bank_vault::withdraw_underlying_coin(&mut self.vault, (redeemAmount as u64))
  }
  
  fun mint<T>(
    self: &mut Bank,
    balance: Balance<T>
  ): Balance<BankCoin<T>> {
    let typeName = type_name::get<T>();
    let coinAmount = (balance::value(&balance) as u128);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    /**********
      mintRate = totalBankSupply / (cash + debt - reserve)
      mintAmount = coinAmount * mintRate
    **********/
    let mintRate = exponential::exp(
      (bank_vault::bank_coin_total_supply<T>(&self.vault) as u128),
      balanceSheet.cash + balanceSheet.debt - balanceSheet.reserve,
    );
    let mintAmount = exponential::mul_scalar_exp_truncate(
      coinAmount,
      mintRate
    );
    // update the bank balance sheet
    balanceSheet.cash = balanceSheet.cash + coinAmount;
    // put the underyling coin, and mint the bank coin
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    bank_vault::issue_bank_coin(&mut self.vault, (mintAmount as u64))
  }
}
