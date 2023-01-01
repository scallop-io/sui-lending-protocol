module protocol::bank {
  
  use std::vector;
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use math::fr::{Self, Fr};
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::WitTable;
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::bank_vault::{Self, BankVault, BankCoin};
  use protocol::borrow_dynamics::{Self, BorrowDynamics, BorrowDynamic};
  
  struct Bank has key {
    id: UID,
    borrowDynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    vault: BankVault
  }
  
  public fun new(ctx: &mut TxContext)
  : (Bank, AcTableCap<InterestModels>, AcTableCap<RiskModels>)
  {
    let (interestModels, interestModelsCap) = interest_model::new(ctx);
    let (riskModels, riskModelsCap) = risk_model::new(ctx);
    let bank = Bank {
      id: object::new(ctx),
      borrowDynamics: borrow_dynamics::new(ctx),
      interestModels,
      riskModels,
      vault: bank_vault::new(ctx),
    };
    (bank, interestModelsCap, riskModelsCap)
  }
  
  public fun handle_borrow<T>(
    self: &mut Bank,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowedBalance = bank_vault::withdraw_underlying_coin(&mut self.vault, borrowAmount);
    update_interest_rates(self);
    borrowedBalance
  }
  
  public fun handle_repay<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    update_interest_rates(self);
  }
  
  public fun handle_liquidation<T>(
    self: &mut Bank,
    balance: Balance<T>,
    reserveBalance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    bank_vault::deposit_underlying_coin(&mut self.vault, reserveBalance);
    update_interest_rates(self);
  }
  
  public fun handle_redeem<T>(
    self: &mut Bank,
    bankCoinBalance: Balance<BankCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = bank_vault::redeem_underlying_coin(&mut self.vault, bankCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public fun handle_mint<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ): Balance<BankCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = bank_vault::mint_bank_coin(&mut self.vault, balance);
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
  
  public fun borrow_index(self: &Bank, typeName: TypeName): Fr {
    borrow_dynamics::borrow_index(&self.borrowDynamics, typeName)
  }
  
  public fun risk_model(self: &Bank, typeName: TypeName): &RiskModel {
    ac_table::borrow(&self.riskModels, typeName)
  }
  
  // accure interest for all banks
  public fun accrue_all_interests(self: &mut Bank, now: u64) {
    let assetTypes = bank_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      // update borrow index
      let oldBorrowIndex = borrow_dynamics::borrow_index(&self.borrowDynamics, type);
      borrow_dynamics::update_borrow_index(&mut self.borrowDynamics, type, now);
      let newBorrowIndex = borrow_dynamics::borrow_index(&self.borrowDynamics, type);
      let debtIncreaseRate = fr::div(newBorrowIndex, oldBorrowIndex);
      // get reserve factor
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let reserveFactor = interest_model::reserve_factor(interestModel);
      // update bank debt
      bank_vault::increase_debt(&mut self.vault, type, debtIncreaseRate, reserveFactor);
      i = i + 1;
    };
  }
  
  // accure interest for all banks
  public fun update_interest_rates(
    self: &mut Bank,
  ) {
    let assetTypes = bank_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let ultiRate = bank_vault::ulti_rate(&self.vault, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let newInterestRate = interest_model::calc_interest(interestModel, ultiRate);
      borrow_dynamics::update_interest_rate(&mut self.borrowDynamics, type, newInterestRate);
      i = i + 1;
    };
  }
}
