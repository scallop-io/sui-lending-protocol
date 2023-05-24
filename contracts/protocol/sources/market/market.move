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

  const EMaxCollateralReached: u64 = 0;
  
  struct Market has key, store {
    id: UID,
    borrow_dynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    collateral_stats: WitTable<CollateralStats, TypeName, CollateralStat>,
    interest_models: AcTable<InterestModels, TypeName, InterestModel>,
    risk_models: AcTable<RiskModels, TypeName, RiskModel>,
    limiters: WitTable<Limiters, TypeName, Limiter>,
    vault: Reserve
  }

  public fun uid(market: &Market): &UID { &market.id }
  public(friend) fun uid_mut(market: &mut Market): &mut UID { &mut market.id }

  public fun borrow_dynamics(market: &Market): &WitTable<BorrowDynamics, TypeName, BorrowDynamic> { &market.borrow_dynamics }
  public fun interest_models(market: &Market): &AcTable<InterestModels, TypeName, InterestModel> { &market.interest_models }
  public fun vault(market: &Market): &Reserve { &market.vault }
  public fun risk_models(market: &Market): &AcTable<RiskModels, TypeName, RiskModel> { &market.risk_models }
  public fun collateral_stats(market: &Market): &WitTable<CollateralStats, TypeName, CollateralStat> { &market.collateral_stats }
  
  public fun borrow_index(self: &Market, type_name: TypeName): u64 {
    borrow_dynamics::borrow_index_by_type(&self.borrow_dynamics, type_name)
  }
  public fun interest_model(self: &Market, type_name: TypeName): &InterestModel {
    ac_table::borrow(&self.interest_models, type_name)
  }
  public fun risk_model(self: &Market, type_name: TypeName): &RiskModel {
    ac_table::borrow(&self.risk_models, type_name)
  }
  public fun has_risk_model(self: &Market, type_name: TypeName): bool {
    ac_table::contains(&self.risk_models, type_name)
  }
  public fun has_limiter(self: &Market, type_name: TypeName): bool {
    wit_table::contains(&self.limiters, type_name)
  } 
  
  public(friend) fun new(ctx: &mut TxContext)
  : (Market, AcTableCap<InterestModels>, AcTableCap<RiskModels>)
  {
    let (interest_models, interest_models_cap) = interest_model::new(ctx);
    let (risk_models, risk_models_cap) = risk_model::new(ctx);
    let market = Market {
      id: object::new(ctx),
      borrow_dynamics: borrow_dynamics::new(ctx),
      collateral_stats: collateral_stats::new(ctx),
      interest_models,
      risk_models,
      limiters: limiter::init_table(ctx),
      vault: reserve::new(ctx),
    };
    (market, interest_models_cap, risk_models_cap)
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
    let interest_model = ac_table::borrow(&self.interest_models, get<T>());
    let base_borrow_rate = interest_model::base_borrow_rate(interest_model);
    borrow_dynamics::register_coin<T>(&mut self.borrow_dynamics, base_borrow_rate, now);
  }
  
  public(friend) fun register_collateral<T>(self: &mut Market) {
    collateral_stats::init_collateral_if_none(&mut self.collateral_stats, get<T>());
  }
  
  public(friend) fun risk_models_mut(self: &mut Market): &mut AcTable<RiskModels, TypeName, RiskModel> {
    &mut self.risk_models
  }
  
  public(friend) fun interest_models_mut(self: &mut Market): &mut AcTable<InterestModels, TypeName, InterestModel> {
    &mut self.interest_models
  }
  
  public(friend) fun handle_borrow<T>(
    self: &mut Market,
    borrow_amount: u64,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let borrowed_balance = reserve::handle_borrow<T>(&mut self.vault, borrow_amount);
    update_interest_rates(self);
    borrowed_balance
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
    collateral_amount: u64
  ) {
    let type = get<T>();
    let risk_model = ac_table::borrow(&self.risk_models, type);
    collateral_stats::increase(&mut self.collateral_stats, type, collateral_amount);
    let total_collateral_amount = collateral_stats::collateral_amount(&self.collateral_stats, type);
    let max_collateral_amount = risk_model::max_collateral_Amount(risk_model);
    assert!(total_collateral_amount <= max_collateral_amount, EMaxCollateralReached);
  }
  
  public(friend) fun handle_withdraw_collateral<T>(
    self: &mut Market,
    amount: u64,
    now: u64
  ) {
    accrue_all_interests(self, now);
    collateral_stats::decrease(&mut self.collateral_stats, get<T>(), amount);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_liquidation<T>(
    self: &mut Market,
    balance: Balance<T>,
    revenue_balance: Balance<T>,
  ) {
    // We don't accrue interest here, because it has already been accrued in previous step for liquidation
    reserve::handle_liquidation(&mut self.vault, balance, revenue_balance);
    update_interest_rates(self);
  }
  
  public(friend) fun handle_redeem<T>(
    self: &mut Market,
    market_coin_balance: Balance<MarketCoin<T>>,
    now: u64,
  ): Balance<T> {
    accrue_all_interests(self, now);
    let reddem_balance = reserve::redeem_underlying_coin(&mut self.vault, market_coin_balance);
    update_interest_rates(self);
    reddem_balance
  }
  
  public(friend) fun handle_mint<T>(
    self: &mut Market,
    balance: Balance<T>,
    now: u64,
  ): Balance<MarketCoin<T>> {
    accrue_all_interests(self, now);
    let mint_balance = reserve::mint_market_coin(&mut self.vault, balance);
    update_interest_rates(self);
    mint_balance
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
    let asset_types = reserve::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&asset_types));
    while (i < n) {
      let type = *vector::borrow(&asset_types, i);
      // update borrow index
      let old_borrow_index = borrow_dynamics::borrow_index_by_type(&self.borrow_dynamics, type);
      borrow_dynamics::update_borrow_index(&mut self.borrow_dynamics, type, now);
      let new_borrow_index = borrow_dynamics::borrow_index_by_type(&self.borrow_dynamics, type);
      let debt_increase_rate = fixed_point32_empower::sub(fixed_point32::create_from_rational(new_borrow_index, old_borrow_index), fixed_point32_empower::from_u64(1));
      // get revenue factor
      let interest_model = ac_table::borrow(&self.interest_models, type);
      let revenue_factor = interest_model::revenue_factor(interest_model);
      // update market debt
      reserve::increase_debt(&mut self.vault, type, debt_increase_rate, revenue_factor);
      i = i + 1;
    };
  }
  
  // accure interest for all markets
  fun update_interest_rates(
    self: &mut Market,
  ) {
    let asset_types = reserve::asset_types(&self.vault);
    let (i, n) = (0, vector::length(&asset_types));
    while (i < n) {
      let type = *vector::borrow(&asset_types, i);
      let ulti_rate = reserve::ulti_rate(&self.vault, type);
      let interest_model = ac_table::borrow(&self.interest_models, type);
      let new_interest_rate = interest_model::calc_interest(interest_model, ulti_rate);
      borrow_dynamics::update_interest_rate(&mut self.borrow_dynamics, type, new_interest_rate);
      i = i + 1;
    };
  }
}
