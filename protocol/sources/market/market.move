module protocol::market {
  
  use std::vector;
  use std::fixed_point32;
  use std::type_name::{TypeName, get, Self};
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::{Self, WitTable};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::limiter::{Self, Limiters, Limiter};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::reserve::{Self, Reserve, MarketCoin};
  use protocol::borrow_dynamics::{Self, BorrowDynamics, BorrowDynamic};
  use protocol::collateral_stats::{CollateralStats, CollateralStat};
  use protocol::collateral_stats;
  use math::fixed_point32_empower;
  
  friend protocol::app;
  friend protocol::borrow;
  friend protocol::repay;
  friend protocol::liquidate;
  friend protocol::mint;
  friend protocol::redeem;
  friend protocol::withdraw_collateral;
  friend protocol::deposit_collateral;

  // TODO: remove this when launch on mainnet
  friend protocol::app_test;
  
  const EMaxCollateralReached: u64 = 0;
  
  struct Market has key, store {
    id: UID,
    borrowDynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    collateralStats: WitTable<CollateralStats, TypeName, CollateralStat>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    riskModels: AcTable<RiskModels, TypeName, RiskModel>,
    limiters: WitTable<Limiters, TypeName, Limiter>,
    vault: Reserve
  }
  
  public fun borrow_dynamics(market: &Market): &WitTable<BorrowDynamics, TypeName, BorrowDynamic> { &market.borrowDynamics }
  public fun interest_models(market: &Market): &AcTable<InterestModels, TypeName, InterestModel> { &market.interestModels }
  public fun vault(market: &Market): &Reserve { &market.vault }
  public fun risk_models(market: &Market): &AcTable<RiskModels, TypeName, RiskModel> { &market.riskModels }
  public fun collateral_stats(market: &Market): &WitTable<CollateralStats, TypeName, CollateralStat> { &market.collateralStats }
  
  public fun borrow_index(self: &Market, typeName: TypeName): u64 {
    borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, typeName)
  }
  public fun interest_model(self: &Market, typeName: TypeName): &InterestModel {
    ac_table::borrow(&self.interestModels, typeName)
  }
  public fun risk_model(self: &Market, typeName: TypeName): &RiskModel {
    ac_table::borrow(&self.riskModels, typeName)
  }
  public fun has_risk_model(self: &Market, typeName: TypeName): bool {
    ac_table::contains(&self.riskModels, typeName)
  }
  public fun has_limiter(self: &Market, type_name: TypeName): bool {
    wit_table::contains(&self.limiters, type_name)
  } 
  
  public(friend) fun new(ctx: &mut TxContext)
  : (Market, AcTableCap<InterestModels>, AcTableCap<RiskModels>)
  {
    let (interestModels, interestModelsCap) = interest_model::new(ctx);
    let (riskModels, riskModelsCap) = risk_model::new(ctx);
    let market = Market {
      id: object::new(ctx),
      borrowDynamics: borrow_dynamics::new(ctx),
      collateralStats: collateral_stats::new(ctx),
      interestModels,
      riskModels,
      limiters: limiter::init_table(ctx),
      vault: reserve::new(ctx),
    };
    (market, interestModelsCap, riskModelsCap)
  }

  public(friend) fun add_limiter<T>(
    self: &mut Market, 
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ) {
    let key = type_name::get<T>();
    limiter::add_limiter(
        &mut self.limiters,
        key,
        outflow_limit,
        outflow_cycle_duration,
        outflow_segment_duration,
    );
  }

  public(friend) fun update_outflow_segment_params<T>(
    self: &mut Market,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ) {
    let key = type_name::get<T>();
    limiter::update_outflow_segment_params(
        &mut self.limiters,
        key,
        outflow_cycle_duration,
        outflow_segment_duration,
    );
  }

  public(friend) fun update_outflow_limit_params<T>(
    self: &mut Market,
    outflow_limit: u64,
  ) {
    let key = type_name::get<T>();
    limiter::update_outflow_limit_params(
        &mut self.limiters,
        key,
        outflow_limit,
    );
  }

  public(friend) fun handle_outflow<T>(
    self: &mut Market,
    outflow_value: u64,
    now: u64,
  ) {
    let key = type_name::get<T>();
    limiter::add_outflow(
        &mut self.limiters,
        key,
        now,
        outflow_value,
    );
  }

  public(friend) fun handle_inflow<T>(
    self: &mut Market,
    inflow_value: u64,
    now: u64,
  ) {
    let key = type_name::get<T>();
    limiter::reduce_outflow(
        &mut self.limiters,
        key,
        now,
        inflow_value,
    );
  }
  
  public(friend) fun register_coin<T>(self: &mut Market, now: u64) {
    reserve::register_coin<T>(&mut self.vault);
    let interestModel = ac_table::borrow(&self.interestModels, get<T>());
    let baseBorrowRate = interest_model::base_borrow_rate(interestModel);
    borrow_dynamics::register_coin<T>(&mut self.borrowDynamics, baseBorrowRate, now);
  }
  
  public(friend) fun register_collateral<T>(self: &mut Market) {
    collateral_stats::init_collateral_if_none(&mut self.collateralStats, get<T>());
  }
  
  public(friend) fun risk_models_mut(self: &mut Market): &mut AcTable<RiskModels, TypeName, RiskModel> {
    &mut self.riskModels
  }
  
  public(friend) fun interest_models_mut(self: &mut Market): &mut AcTable<InterestModels, TypeName, InterestModel> {
    &mut self.interestModels
  }
  
  public(friend) fun handle_borrow<T>(
    self: &mut Market,
    borrowAmount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowedBalance = reserve::handle_borrow<T>(&mut self.vault, borrowAmount);
    update_interest_rates(self);
    borrowedBalance
  }
  
  /// IMPORTANT: `accrue_all_interests` is not called here!
  /// `accrue_all_interests` can be called independently so we can expect 
  /// how much of the current debt after the interest accrued before repaying
  public(friend) fun handle_repay<T>(
    self: &mut Market,
    balance: Balance<T>,
  ) {
    reserve::handle_repay(&mut self.vault, balance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_add_collateral<T>(
    self: &mut Market,
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
    self: &mut Market,
    amount: u64,
    now: u64
  ) {
    accrue_all_interests(self, now);
    collateral_stats::decrease(&mut self.collateralStats, get<T>(), amount);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_liquidation<T>(
    self: &mut Market,
    balance: Balance<T>,
    revenueBalance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    reserve::handle_liquidation(&mut self.vault, balance, revenueBalance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_redeem<T>(
    self: &mut Market,
    marketCoinBalance: Balance<MarketCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddemBalance = reserve::redeem_underlying_coin(&mut self.vault, marketCoinBalance);
    update_interest_rates(self);
    reddemBalance
  }
  
  public(friend) fun handle_mint<T>(
    self: &mut Market,
    balance: Balance<T>,
    now: u64,
  ): Balance<MarketCoin<T>> {
    accrue_all_interests(self, now);
    let mintBalance = reserve::mint_market_coin(&mut self.vault, balance);
    update_interest_rates(self);
    mintBalance
  }
  
  public(friend) fun compound_interests(
    self: &mut Market,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }
  
  // accure interest for all markets
  public(friend) fun accrue_all_interests(
    self: &mut Market,
    now: u64
  ) {
    let assetTypes = reserve::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      // update borrow index
      let oldBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      borrow_dynamics::update_borrow_index(&mut self.borrowDynamics, type, now);
      let newBorrowIndex = borrow_dynamics::borrow_index_by_type(&self.borrowDynamics, type);
      let debtIncreaseRate = fixed_point32_empower::sub(fixed_point32::create_from_rational(newBorrowIndex, oldBorrowIndex), fixed_point32_empower::from_u64(1));
      // get revenue factor
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let revenueFactor = interest_model::revenue_factor(interestModel);
      // update market debt
      reserve::increase_debt(&mut self.vault, type, debtIncreaseRate, revenueFactor);
      i = i + 1;
    };
  }
  
  // accure interest for all markets
  fun update_interest_rates(
    self: &mut Market,
  ) {
    let assetTypes = reserve::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&assetTypes));
    while (i < n) {
      let type = *vector::borrow(&assetTypes, i);
      let ultiRate = reserve::ulti_rate(&self.vault, type);
      let interestModel = ac_table::borrow(&self.interestModels, type);
      let newInterestRate = interest_model::calc_interest(interestModel, ultiRate);
      borrow_dynamics::update_interest_rate(&mut self.borrowDynamics, type, newInterestRate);
      i = i + 1;
    };
  }
}
