module protocol::market {
  
  use std::vector;
  use std::fixed_point32;
  use std::type_name::{TypeName, get, Self};
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use sui::coin::Coin;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::wit_table::{Self, WitTable};
  use x::witness::Witness;
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::limiter::{Self, Limiters, Limiter};
  use protocol::incentive_rewards::{Self, RewardFactors, RewardFactor};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::reserve::{Self, Reserve, MarketCoin, FlashLoan};
  use protocol::borrow_dynamics::{Self, BorrowDynamics, BorrowDynamic};
  use protocol::collateral_stats::{Self, CollateralStats, CollateralStat};
  use protocol::asset_active_state::{Self, AssetActiveStates};
  use protocol::error;
  use math::fixed_point32_empower;

  friend protocol::app;
  friend protocol::borrow;
  friend protocol::repay;
  friend protocol::liquidate;
  friend protocol::mint;
  friend protocol::redeem;
  friend protocol::withdraw_collateral;
  friend protocol::deposit_collateral;
  friend protocol::flash_loan;

  
  struct Market has key, store {
    id: UID,
    borrow_dynamics: WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    collateral_stats: WitTable<CollateralStats, TypeName, CollateralStat>,
    interest_models: AcTable<InterestModels, TypeName, InterestModel>,
    risk_models: AcTable<RiskModels, TypeName, RiskModel>,
    limiters: WitTable<Limiters, TypeName, Limiter>,
    reward_factors: WitTable<RewardFactors, TypeName, RewardFactor>,
    asset_active_states: AssetActiveStates,
    vault: Reserve
  }

  public fun uid(market: &Market): &UID { &market.id }
  public fun uid_mut_delegated(market: &mut Market, _: Witness<Market>): &mut UID { &mut market.id }
  public(friend) fun uid_mut(market: &mut Market): &mut UID { &mut market.id }

  public fun borrow_dynamics(market: &Market): &WitTable<BorrowDynamics, TypeName, BorrowDynamic> { &market.borrow_dynamics }
  public fun interest_models(market: &Market): &AcTable<InterestModels, TypeName, InterestModel> { &market.interest_models }
  public fun vault(market: &Market): &Reserve { &market.vault }
  public fun risk_models(market: &Market): &AcTable<RiskModels, TypeName, RiskModel> { &market.risk_models }
  public fun reward_factors(market: &Market): &WitTable<RewardFactors, TypeName, RewardFactor> { &market.reward_factors }
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
  public fun reward_factor(self: &Market, type_name: TypeName): &RewardFactor {
    wit_table::borrow(&self.reward_factors, type_name)
  }
  public fun has_risk_model(self: &Market, type_name: TypeName): bool {
    ac_table::contains(&self.risk_models, type_name)
  }
  public fun has_limiter(self: &Market, type_name: TypeName): bool {
    wit_table::contains(&self.limiters, type_name)
  }
  public fun is_base_asset_active(self: &Market, type_name: TypeName): bool {
    asset_active_state::is_base_asset_active(&self.asset_active_states, type_name)
  }
  public fun is_collateral_active(self: &Market, type_name: TypeName): bool {
    asset_active_state::is_collateral_active(&self.asset_active_states, type_name)
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
      reward_factors: incentive_rewards::init_table(ctx),
      asset_active_states: asset_active_state::new(ctx),
      vault: reserve::new(ctx),
    };
    (market, interest_models_cap, risk_models_cap)
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

  // ===== management of asset active state =====
  public(friend) fun set_base_asset_active_state<T>(self: &mut Market, is_active: bool) {
    let type = get<T>();
    asset_active_state::set_base_asset_active_state(&mut self.asset_active_states, type, is_active);
  }
  public(friend) fun set_collateral_active_state<T>(self: &mut Market, is_active: bool) {
    let type = get<T>();
    asset_active_state::set_collateral_active_state(&mut self.asset_active_states, type, is_active);
  }


  // register base coin asset
  public(friend) fun register_coin<T>(self: &mut Market, now: u64) {
    let type = get<T>();
    reserve::register_coin<T>(&mut self.vault);
    let interest_model = ac_table::borrow(&self.interest_models, type);
    let base_borrow_rate = interest_model::base_borrow_rate(interest_model);
    let interest_rate_scale = interest_model::interest_rate_scale(interest_model);
    borrow_dynamics::register_coin<T>(&mut self.borrow_dynamics, base_borrow_rate, interest_rate_scale, now);
    asset_active_state::set_base_asset_active_state(&mut self.asset_active_states, type, true);
  }

  // register collateral asset
  public(friend) fun register_collateral<T>(self: &mut Market) {
    let type = get<T>();
    collateral_stats::init_collateral_if_none(&mut self.collateral_stats, type);
    asset_active_state::set_collateral_active_state(&mut self.asset_active_states, type, true);
  }

  // the final fee rate is "fee/10000"
  // When fee is 10, the final fee rate is 0.1%
  public(friend) fun set_flash_loan_fee<T>(self: &mut Market, fee: u64) {
    reserve::set_flash_loan_fee<T>(&mut self.vault, fee)
  }
  
  public(friend) fun risk_models_mut(self: &mut Market): &mut AcTable<RiskModels, TypeName, RiskModel> {
    &mut self.risk_models
  }
  
  public(friend) fun interest_models_mut(self: &mut Market): &mut AcTable<InterestModels, TypeName, InterestModel> {
    &mut self.interest_models
  }

  public(friend) fun rate_limiter_mut(self: &mut Market): &mut WitTable<Limiters, TypeName, Limiter> {
    &mut self.limiters
  }

  public(friend) fun reward_factors_mut(self: &mut Market): &mut WitTable<RewardFactors, TypeName, RewardFactor> {
    &mut self.reward_factors
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
    assert!(total_collateral_amount <= max_collateral_amount, error::max_collateral_reached_error());
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

  public(friend) fun borrow_flash_loan<T>(
    self: &mut Market,
    amount: u64,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    reserve::borrow_flash_loan<T>(&mut self.vault, amount, ctx)
  }

  public(friend) fun repay_flash_loan<T>(
    self: &mut Market,
    coin: Coin<T>,
    loan: FlashLoan<T>,
  ) {
    reserve::repay_flash_loan(&mut self.vault, coin, loan)
  }

  public(friend) fun compound_interests(
    self: &mut Market,
    now: u64,
  ) {
    accrue_all_interests(self, now);
    update_interest_rates(self);
  }

  public(friend) fun take_revenue<T>(
    self: &mut Market,
    amount: u64,
    ctx: &mut TxContext,
  ): Coin<T> {
    reserve::take_revenue<T>(&mut self.vault, amount, ctx)
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
      let util_rate = reserve::util_rate(&self.vault, type);
      let interest_model = ac_table::borrow(&self.interest_models, type);
      let (new_interest_rate, interest_rate_scale) = interest_model::calc_interest(interest_model, util_rate);
      borrow_dynamics::update_interest_rate(&mut self.borrow_dynamics, type, new_interest_rate, interest_rate_scale);
      i = i + 1;
    };
  }
}
