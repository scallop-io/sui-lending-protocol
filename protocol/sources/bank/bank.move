module protocol::bank {
  
  use std::vector;
  use std::type_name::{Self, TypeName};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::wit_table::{Self, WitTable};
  use x::ownership::Ownership;
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::bank_vault::{Self, BankVault, BankCoin};
  use math::fr::{Self, Fr};
  use math::mix;
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has store {
    cash: u64,
    debt: u64,
    reserve: u64,
  }
  
  struct BorrowIndexes has drop {}
  
  struct BorrowIndex has store {
    mark: u64,
    interestRate: Fr,
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
  
  public fun borrow_mark(self: &Bank, typeName: TypeName): u64 {
    let borrowIndex = wit_table::borrow(&self.borrowIndexes, typeName);
    borrowIndex.mark
  }
  
  public fun collateral_factor(self: &Bank, typeName: TypeName): Fr {
    risk_model::collateral_factor(&self.riskModels, typeName)
  }
  
  // update bank balance sheet for repay
  fun update_balance_sheet_for_repay(
    self: &mut Bank,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt - repayAmount;
    balanceSheet.cash = balanceSheet.cash + repayAmount;
  }
  
  // update bank balance sheet for borrow
  fun update_balance_sheet_for_borrow(
    self: &mut Bank,
    typeName: TypeName,
    borrowAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt + borrowAmount;
    balanceSheet.cash = balanceSheet.cash - borrowAmount;
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
    let timeDelta = now - borrowIndex.lastUpdated;
    
    /*********
    increaseFactor = 1 + timeDelta * interestRate
    *********/
    let increaseFactor = fr::add(
      fr::int(1),
      fr::mul(borrowIndex.interestRate, fr::int(timeDelta))
    );
    
    /*********
    newDebt = oldDebt * increaseFactor
    *********/
    let oldDebt = balanceSheet.debt;
    balanceSheet.debt = mix::mul_ifrT(oldDebt, increaseFactor);
    
    /*********
    newMark = oldMark * increaseFactor
    *********/
    borrowIndex.mark = mix::mul_ifrT(borrowIndex.mark, increaseFactor);
    
    /*******
     newReserve = reserve + reserveFactor * (newDebt - oldDebt)
    ********/
    let reserveFactor = interest_model::reserve_factor(interestModel);
    let reserveDelta = mix::mul_ifrT(balanceSheet.debt - oldDebt, reserveFactor);
    balanceSheet.reserve = balanceSheet.reserve + reserveDelta;
    
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
    let ultiRate = fr::fr(
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
    let redeemRate = fr::fr(
      balanceSheet.cash + balanceSheet.debt - balanceSheet.reserve,
      bank_vault::bank_coin_total_supply<T>(&self.vault),
    );
    let redeemAmount = mix::mul_ifrT(bankCoinAmount, redeemRate);
    // update the bank balance sheet
    balanceSheet.cash = balanceSheet.cash - redeemAmount;
    // burn the bank coin, and return the underyling coin
    bank_vault::burn_bank_coin(&mut self.vault, bankCoinBalance);
    bank_vault::withdraw_underlying_coin(&mut self.vault, redeemAmount)
  }
  
  fun mint<T>(
    self: &mut Bank,
    balance: Balance<T>
  ): Balance<BankCoin<T>> {
    let typeName = type_name::get<T>();
    let coinAmount = balance::value(&balance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, typeName);
    /**********
      mintRate = totalBankSupply / (cash + debt - reserve)
      mintAmount = coinAmount * mintRate
    **********/
    let mintRate = fr::fr(
      bank_vault::bank_coin_total_supply<T>(&self.vault),
      balanceSheet.cash + balanceSheet.debt - balanceSheet.reserve,
    );
    let mintAmount = mix::mul_ifrT(coinAmount, mintRate);
    // update the bank balance sheet
    balanceSheet.cash = balanceSheet.cash + coinAmount;
    // put the underyling coin, and mint the bank coin
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    bank_vault::issue_bank_coin(&mut self.vault, mintAmount)
  }
}
