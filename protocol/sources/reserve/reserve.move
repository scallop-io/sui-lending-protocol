module protocol::reserve {
  
  use std::vector;
  use std::fixed_point32;
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::WitTable;
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::reserve_vault::{Self, ReserveVault, ReserveCoin};
  use protocol::borrow_dynamics::{Self, BorrowDynamics, BorrowDynamic};
  use protocol::collateral_stats::{CollateralStats, CollateralStat};
  use protocol::collateral_stats;
  
  friend protocol::app;
  friend protocol::borrow;
  friend protocol::repay;
  friend protocol::liquidate;
  friend protocol::mint;
  friend protocol::redeem;
  friend protocol::withdraw_collateral;
  friend protocol::deposit_collateral;
  
  const EMaxCollateralReached: u64 = 0;
  
  struct Reserve has key, store {
    id: UID,
    borrowDynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    collateralStats: WitTable<CollateralStats, TypeName, CollateralStat>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    vault: ReserveVault
  }
  
  public fun borrow_dynamics(reserve: &Reserve): &WitTable<BorrowDynamics, TypeName, BorrowDynamic> { &reserve.borrowDynamics }
  public fun interest_models(reserve: &Reserve): &AcTable<InterestModels, TypeName, InterestModel> { &reserve.interestModels }
  public fun vault(reserve: &Reserve): &ReserveVault { &reserve.vault }
  public fun risk_models(reserve: &Reserve): &AcTable<RiskModels, TypeName, RiskModel> { &reserve.riskModels }
  public fun collateral_stats(reserve: &Reserve): &WitTable<CollateralStats, TypeName, CollateralStat> { &reserve.collateralStats }
  
  public fun borrow_index(self: &Reserve, typeName: TypeName): u64 {
    borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, typeName)
  }
  public fun interest_model(self: &Reserve, typeName: TypeName): &InterestModel {
    ac_table::borrow(&self.interestModels, typeName)
  }
  public fun risk_model(self: &Reserve, typeName: TypeName): &RiskModel {
    ac_table::borrow(&self.riskModels, typeName)
  }
  public fun has_risk_model(self: &Reserve, typeName: TypeName): bool {
    ac_table::contains(&self.riskModels, typeName)
  }
  
  public(friend) fun new(ctx: &mut TxContext)
  : (Reserve, AcTableCap<InterestModels>, AcTableCap<RiskModels>)
  {
    let (interestModels, interestModelsCap) = interest_model::new(ctx);
    let (riskModels, riskModelsCap) = risk_model::new(ctx);
    let reserve = Reserve {
      id: object::new(ctx),
      borrowDynamics: borrow_dynamics::new(ctx),
      collateralStats: collateral_stats::new(ctx),
      interestModels,
      riskModels,
      vault: reserve_vault::new(ctx),
    };
    (reserve, interestModelsCap, riskModelsCap)
  }
  
  public(friend) fun register_coin<T>(self: &mut Reserve, now: u64) {
    reserve_vault::register_coin<T>(&mut self.vault);
    let interestModel = ac_table::borrow(&self.interestModels, get<T>());
    let baseBorrowRate = interest_model::base_borrow_rate(interestModel);
    borrow_dynamics::register_coin<T>(&mut self.borrowDynamics, baseBorrowRate, now);
  }
  
  public(friend) fun register_collateral<T>(self: &mut Reserve) {
    collateral_stats::init_collateral_if_none(&mut self.collateralStats, get<T>());
  }
  
  public(friend) fun risk_models_mut(self: &mut Reserve): &mut AcTable<RiskModels, TypeName, RiskModel> {
    &mut self.riskModels
  }
  
  public(friend) fun interest_models_mut(self: &mut Reserve): &mut AcTable<InterestModels, TypeName, InterestModel> {
    &mut self.interestModels
  }
  
  public(friend) fun handle_borrow<T>(
    self: &mut Reserve,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowedBalance = reserve_vault::withdraw_underlying_coin(&mut self.vault, borrowAmount);
    update_interest_rates(self);
    borrowedBalance
  }
  
  public(friend) fun handle_repay<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    reserve_vault::deposit_underlying_coin(&mut self.vault, balance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_add_collateral<T>(
    self: &mut Reserve,
    collateralAmount: u64
  ) {
    let type = get<T>();
    let riskModel = ac_table::borrow(&self.riskModels, type);
    collateral_stats::increase(&mut self.collateralStats, type, collateralAmount);
    let totalCollateralAmount = collateral_stats::collateral_amount(&self.collateralStats, type);
    let maxCollateralAmount = risk_model::max_collateral_Amount(riskModel);
    assert!(totalCollateralAmount <= maxCollateralAmount, EMaxCollateralReached);
  }
  
  public(friend) fun handle_withdraw_collateral<T>(
    self: &mut Reserve,
    amount: u64,
    now: u64
  ) {
    accrue_all_interests(self, now);
    collateral_stats::decrease(&mut self.collateralStats, get<T>(), amount);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_liquidation<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    reserveBalance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    reserve_vault::deposit_underlying_coin(&mut self.vault, balance);
    reserve_vault::deposit_underlying_coin(&mut self.vault, reserveBalance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_redeem<T>(
    self: &mut Reserve,
    reserveCoinBalance: Balance<ReserveCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = reserve_vault::redeem_underlying_coin(&mut self.vault, reserveCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public(friend) fun handle_mint<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    now: u64,
  ): Balance<ReserveCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = reserve_vault::mint_reserve_coin(&mut self.vault, balance);
    update_interest_rates(self);
    mintBalance
  }
  
  public(friend) fun compound_interests(
    self: &mut Reserve,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }
  
  // accure interest for all reserves
  public(friend) fun accrue_all_interests(
    self: &mut Reserve,
    now: u64
  ) {
    let assetTypes = reserve_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      // update borrow index
      let oldBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      borrow_dynamics::update_borrow_index(&mut self.borrowDynamics, type, now);
      let newBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      let debtIncreaseRate = fixed_point32::create_from_rational(newBorrowIndex, oldBorrowIndex);
      // get reserve factor
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let reserveFactor = interest_model::reserve_factor(interestModel);
      // update reserve debt
      reserve_vault::increase_debt(&mut self.vault, type, debtIncreaseRate, reserveFactor);
      i = i + 1;
    };
  }
  
  // accure interest for all reserves
  fun update_interest_rates(
    self: &mut Reserve,
  ) {
    let assetTypes = reserve_vault::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let ultiRate = reserve_vault::ulti_rate(&self.vault, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let newInterestRate = interest_model::calc_interest(interestModel, ultiRate);
      borrow_dynamics::update_interest_rate(&mut self.borrowDynamics, type, newInterestRate);
      i = i + 1;
    };
  }
}
