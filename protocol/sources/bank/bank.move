module protocol::bank {
  
  use std::vector;
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use math::fr;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::WitTable;
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::bank_vault::{Self, BankVault, BankCoin};
  use protocol::borrow_dynamics::{Self, BorrowDynamics, BorrowDynamic};
  
  friend protocol::app;
  friend protocol::borrow;
  friend protocol::repay;
  friend protocol::liquidate;
  friend protocol::mint;
  friend protocol::redeem;
  friend protocol::withdraw_collateral;
  
  struct Bank has key, store {
    id: UID,
    borrowDynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    vault: BankVault
  }
  
  public fun borrow_dynamics(bank: &Bank): &WitTable<BorrowDynamics, TypeName, BorrowDynamic> { &bank.borrowDynamics }
  public fun interest_models(bank: &Bank): &AcTable<InterestModels, TypeName, InterestModel> { &bank.interestModels }
  public fun risk_models(bank: &Bank): &AcTable<RiskModels, TypeName, RiskModel> { &bank.riskModels }
  public fun vault(bank: &Bank): &BankVault { &bank.vault }
  
  public fun borrow_index(self: &Bank, typeName: TypeName): u64 {
    borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, typeName)
  }
  public fun risk_model(self: &Bank, typeName: TypeName): &RiskModel {
    ac_table::borrow(&self.riskModels, typeName)
  }
  public fun interest_model(self: &Bank, typeName: TypeName): &InterestModel {
    ac_table::borrow(&self.interestModels, typeName)
  }
  public fun has_risk_model(self: &Bank, typeName: TypeName): bool {
    ac_table::contains(&self.riskModels, typeName)
  }
  
  public(friend) fun new(ctx: &mut TxContext)
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
  
  public(friend) fun register_coin<T>(self: &mut Bank, now: u64) {
    bank_vault::register_coin<T>(&mut self.vault);
    let interestModel = ac_table::borrow(&self.interestModels, get<T>());
    let baseBorrowRate = interest_model::base_borrow_rate(interestModel);
    borrow_dynamics::register_coin<T>(&mut self.borrowDynamics, baseBorrowRate, now);
  }
  
  public(friend) fun risk_models_mut(self: &mut Bank): &mut AcTable<RiskModels, TypeName, RiskModel> {
    &mut self.riskModels
  }
  
  public(friend) fun interest_models_mut(self: &mut Bank): &mut AcTable<InterestModels, TypeName, InterestModel> {
    &mut self.interestModels
  }
  
  public(friend) fun handle_borrow<T>(
    self: &mut Bank,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowedBalance = bank_vault::withdraw_underlying_coin(&mut self.vault, borrowAmount);
    update_interest_rates(self);
    borrowedBalance
  }
  
  public(friend) fun handle_repay<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_liquidation<T>(
    self: &mut Bank,
    balance: Balance<T>,
    reserveBalance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    bank_vault::deposit_underlying_coin(&mut self.vault, balance);
    bank_vault::deposit_underlying_coin(&mut self.vault, reserveBalance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_redeem<T>(
    self: &mut Bank,
    bankCoinBalance: Balance<BankCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = bank_vault::redeem_underlying_coin(&mut self.vault, bankCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public(friend) fun handle_mint<T>(
    self: &mut Bank,
    balance: Balance<T>,
    now: u64,
  ): Balance<BankCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = bank_vault::mint_bank_coin(&mut self.vault, balance);
    update_interest_rates(self);
    mintBalance
  }
  
  public(friend) fun compound_interests(
    self: &mut Bank,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }
  
  // accure interest for all banks
  public(friend) fun accrue_all_interests(
    self: &mut Bank,
    now: u64
  ) {
    let assetTypes = bank_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      // update borrow index
      let oldBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      borrow_dynamics::update_borrow_index(&mut self.borrowDynamics, type, now);
      let newBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      let debtIncreaseRate = fr::fr(newBorrowIndex, oldBorrowIndex);
      // get reserve factor
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let reserveFactor = interest_model::reserve_factor(interestModel);
      // update bank debt
      bank_vault::increase_debt(&mut self.vault, type, debtIncreaseRate, reserveFactor);
      i = i + 1;
    };
  }
  
  // accure interest for all banks
  fun update_interest_rates(
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
