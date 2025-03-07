module protocol::app {
  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use std::type_name::{Self, TypeName};
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID, ID};
  use sui::clock::{Self, Clock};
  use sui::dynamic_field;
  use sui::transfer;
  use sui::package;
  use sui::event;
  use x::ac_table::AcTableCap;
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::market::{Self, Market};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  use protocol::limiter::{Self, LimiterUpdateParamsChange, LimiterUpdateLimitChange};
  use protocol::incentive_rewards;
  use protocol::error;
  use whitelist::whitelist;
  use protocol::obligation_access::ObligationAccessStore;
  use protocol::obligation_access;
  use protocol::market_dynamic_keys::{Self, BorrowFeeKey, BorrowFeeRecipientKey, SupplyLimitKey, BorrowLimitKey, IsolatedAssetKey};
  use protocol::borrow_referral::{Self, AuthorizedWitnessList};

  /// OTW
  struct APP has drop {}

  struct AdminCap has key, store {
    id: UID,
    interest_model_cap: AcTableCap<InterestModels>,
    interest_model_change_delay: u64,
    risk_model_cap: AcTableCap<RiskModels>,
    risk_model_change_delay: u64,
    limiter_change_delay: u64,
  }

  struct TakeRevenueEvent has copy, drop {
    market: ID,
    amount: u64,
    coin_type: TypeName,
    sender: address,
  }

  struct TakeBorrowFeeEvent has copy, drop {
    market: ID,
    amount: u64,
    coin_type: TypeName,
    sender: address,
  }

  fun init(otw: APP, ctx: &mut TxContext) {
    init_internal(otw, ctx)
  }
  
  #[test_only]
  public fun init_t(ctx: &mut TxContext) {
    init_internal(APP {}, ctx)
  }
  
  #[allow(lint(self_transfer, share_owned))]
  fun init_internal(otw: APP, ctx: &mut TxContext) {
    let (market, interest_model_cap, risk_model_cap) = market::new(ctx);
    let adminCap = AdminCap {
      id: object::new(ctx),
      interest_model_cap,
      interest_model_change_delay: 0,
      risk_model_cap,
      risk_model_change_delay: 0,
      limiter_change_delay: 0,
    };
    package::claim_and_keep(otw, ctx);
    transfer::public_share_object(market);
    transfer::transfer(adminCap, tx_context::sender(ctx));
  }

  /// ===== AdminCap =====
  public fun extend_interest_model_change_delay(
    admin_cap: &mut AdminCap,
    delay: u64,
  ) {
    assert!(delay <= 1, error::invalid_params_error()); // can only extend 1 epoch per change
    admin_cap.interest_model_change_delay = admin_cap.interest_model_change_delay + delay;
  }

  public fun extend_risk_model_change_delay(
    admin_cap: &mut AdminCap,
    delay: u64,
  ) {
    admin_cap.risk_model_change_delay = admin_cap.risk_model_change_delay + delay;
  }

  public fun extend_limiter_change_delay(
    admin_cap: &mut AdminCap,
    delay: u64,
  ) {
    admin_cap.limiter_change_delay = admin_cap.limiter_change_delay + delay;
  }

  /// For extension of the protocol
  public fun ext(
    _: &AdminCap,
    market: &mut Market,
  ): &mut UID {
    market::uid_mut(market)
  }

  /// Add a whitelist address
  public fun add_whitelist_address(
    _: &AdminCap,
    market: &mut Market,
    address: address,
  ) {
    whitelist::add_whitelist_address(
      market::uid_mut(market),
      address,
    );
  }

  public fun remove_whitelist_address(
    _: &AdminCap,
    market: &mut Market,
    address: address,
  ) {
    whitelist::remove_whitelist_address(
      market::uid_mut(market),
      address,
    );
  }

  public fun create_interest_model_change<T>(
    admin_cap: &AdminCap,
    base_rate_per_sec: u64,
    interest_rate_scale: u64,
    borrow_rate_on_mid_kink: u64,
    mid_kink: u64,
    borrow_rate_on_high_kink: u64,
    high_kink: u64,
    max_borrow_rate: u64,
    revenue_factor: u64,
    borrow_weight: u64,
    scale: u64,
    min_borrow_amount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let interest_model_change = interest_model::create_interest_model_change<T>(
      &admin_cap.interest_model_cap,
      base_rate_per_sec,
      interest_rate_scale,
      borrow_rate_on_mid_kink,
      mid_kink,
      borrow_rate_on_high_kink,
      high_kink,
      max_borrow_rate,
      revenue_factor,
      borrow_weight,
      scale,
      min_borrow_amount,
      admin_cap.interest_model_change_delay,
      ctx,
    );
    interest_model_change
  }
  public fun add_interest_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    interest_model_change: OneTimeLockValue<InterestModel>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    update_interest_model<T>(market, admin_cap, interest_model_change, ctx);
    let now = clock::timestamp_ms(clock) / 1000;
    market::register_coin<T>(market, now);
  }
  
  public fun update_interest_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    interest_model_change: OneTimeLockValue<InterestModel>,
    ctx: &mut TxContext,
  ) {
    let interest_models = market::interest_models_mut(market);
    interest_model::add_interest_model<T>(
      interest_models,
      &admin_cap.interest_model_cap,
      interest_model_change,
      ctx
    );
  }

  public fun create_risk_model_change<T>(
    admin_cap: &AdminCap,
    collateral_factor: u64, // exp. 70%,
    liquidation_factor: u64, // exp. 80%,
    liquidation_penalty: u64, // exp. 7%,
    liquidation_discount: u64, // exp. 5%,
    scale: u64,
    max_collateral_amount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let risk_model_change = risk_model::create_risk_model_change<T>(
      &admin_cap.risk_model_cap,
      collateral_factor, // exp. 70%,
      liquidation_factor, // exp. 80%,
      liquidation_penalty, // exp. 7%,
      liquidation_discount, // exp. 5%,
      scale,
      max_collateral_amount,
      admin_cap.risk_model_change_delay,
      ctx
    );
    risk_model_change
  }
  
  public entry fun add_risk_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    risk_model_change: OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext
  ) {
    update_risk_model<T>(market, admin_cap, risk_model_change, ctx);
    market::register_collateral<T>(market);
  }
  
  public entry fun update_risk_model<T>(
    market: &mut Market,
    admin_cap: &AdminCap,
    risk_model_change: OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext
  ) {
    let risk_models = market::risk_models_mut(market);
    risk_model::add_risk_model<T>(
      risk_models,
      &admin_cap.risk_model_cap,
      risk_model_change,
      ctx
    );
  }

  public entry fun add_limiter<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
    _ctx: &mut TxContext
  ) {
    let limiter = market::rate_limiter_mut(market);
    limiter::add_limiter<T>(
      limiter,
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
    );
  }

  public fun create_limiter_params_change<T>(
    admin_cap: &AdminCap,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
    ctx: &mut TxContext
  ): OneTimeLockValue<LimiterUpdateParamsChange> {
    let one_time_lock_value = limiter::create_limiter_params_change<T>(
      outflow_cycle_duration,
      outflow_segment_duration,
      admin_cap.limiter_change_delay,
      ctx
    );
    one_time_lock_value
  }

  public fun create_limiter_limit_change<T>(
    admin_cap: &AdminCap,
    outflow_limit: u64,
    ctx: &mut TxContext
  ): OneTimeLockValue<LimiterUpdateLimitChange> {
    let one_time_lock_value = limiter::create_limiter_limit_change<T>(
      outflow_limit,
      admin_cap.limiter_change_delay,
      ctx
    );
    one_time_lock_value
  }

  #[allow(unused_type_parameter)]
  public entry fun apply_limiter_limit_change<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    one_time_lock_value: OneTimeLockValue<LimiterUpdateLimitChange>,
    ctx: &mut TxContext
  ) {
    let limiter = market::rate_limiter_mut(market);
    limiter::apply_limiter_limit_change(
      limiter,
      one_time_lock_value,
      ctx
    );
  }

  #[allow(unused_type_parameter)]
  public entry fun apply_limiter_params_change<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    one_time_lock_value: OneTimeLockValue<LimiterUpdateParamsChange>,
    ctx: &mut TxContext
  ) {
    let limiter = market::rate_limiter_mut(market);
    limiter::apply_limiter_params_change(
      limiter,
      one_time_lock_value,
      ctx
    );
  }

  // ====== incentive rewards =====
  public entry fun set_incentive_reward_factor<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    reward_factor: u64,
    scale: u64,
    _ctx: &mut TxContext
  ) {
    let reward_factors = market::reward_factors_mut(market);
    incentive_rewards::set_reward_factor<T>(reward_factors, reward_factor, scale);
  }

  // the final fee rate is "fee/10000"
  // When fee is 10, the final fee rate is 0.1%
  public entry fun set_flash_loan_fee<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    fee: u64
  ) {
    market::set_flash_loan_fee<T>(market, fee);
  }

  /// ======= management of asset active state =======
  public entry fun set_base_asset_active_state<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    is_active: bool,
  ) {
    market::set_base_asset_active_state<T>(market, is_active);
  }

  public entry fun set_collateral_active_state<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    is_active: bool,
  ) {
    market::set_collateral_active_state<T>(market, is_active);
  }

  /// ======= take revenue =======
  public entry fun take_revenue<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    amount: u64,
    ctx: &mut TxContext
  ) {
    event::emit(TakeRevenueEvent {
      market: object::id(market),
      amount,
      coin_type: type_name::get<T>(),
      sender: tx_context::sender(ctx),
    });

    let coin = market::take_revenue<T>(market, amount, ctx);
    transfer::public_transfer(coin, tx_context::sender(ctx));
  }

  /// ======= take borrow fee =======
  public entry fun take_borrow_fee<T>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    amount: u64,
    ctx: &mut TxContext
  ) {
    event::emit(TakeBorrowFeeEvent {
      market: object::id(market),
      amount,
      coin_type: type_name::get<T>(),
      sender: tx_context::sender(ctx),
    });

    let coin = market::take_borrow_fee<T>(market, amount, ctx);
    transfer::public_transfer(coin, tx_context::sender(ctx));
  }

  /// ======= Management of obligation access keys
  public entry fun add_lock_key<T: drop>(
    _admin_cap: &AdminCap,
    obligation_access_store: &mut ObligationAccessStore,
  ) {
    obligation_access::add_lock_key<T>(obligation_access_store);
  }

  public entry fun remove_lock_key<T: drop>(
    _admin_cap: &AdminCap,
    obligation_access_store: &mut ObligationAccessStore,
  ) {
    obligation_access::remove_lock_key<T>(obligation_access_store);
  }

  public entry fun add_reward_key<T: drop>(
    _admin_cap: &AdminCap,
    obligation_access_store: &mut ObligationAccessStore,
  ) {
    obligation_access::add_reward_key<T>(obligation_access_store);
  }

  public entry fun remove_reward_key<T: drop>(
    _admin_cap: &AdminCap,
    obligation_access_store: &mut ObligationAccessStore,
  ) {
    obligation_access::remove_reward_key<T>(obligation_access_store);
  }

  public entry fun update_borrow_fee<T: drop>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    fee_numerator: u64,
    fee_denominator: u64,
  ) {
    assert!(fee_numerator <= fee_denominator, error::invalid_params_error());

    let market_uid_mut = market::uid_mut(market);
    let key = market_dynamic_keys::borrow_fee_key(type_name::get<T>());
    let fee = fixed_point32::create_from_rational(fee_numerator, fee_denominator);

    dynamic_field::remove_if_exists<BorrowFeeKey, FixedPoint32>(market_uid_mut, key);
    dynamic_field::add(market_uid_mut, key, fee);
  }

  public entry fun update_borrow_fee_recipient(
    _admin_cap: &AdminCap,
    market: &mut Market,
    recipient: address,
  ) {
    let market_uid_mut = market::uid_mut(market);
    let key = market_dynamic_keys::borrow_fee_recipient_key();

    dynamic_field::remove_if_exists<BorrowFeeRecipientKey, address>(market_uid_mut, key);
    dynamic_field::add(market_uid_mut, key, recipient);
  }

  public entry fun update_supply_limit<T: drop>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    limit_amount: u64,
  ) {
    let market_uid_mut = market::uid_mut(market);
    let key = market_dynamic_keys::supply_limit_key(type_name::get<T>());

    dynamic_field::remove_if_exists<SupplyLimitKey, u64>(market_uid_mut, key);
    dynamic_field::add(market_uid_mut, key, limit_amount);
  }

  public entry fun update_borrow_limit<T: drop>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    limit_amount: u64,
  ) {
    let market_uid_mut = market::uid_mut(market);
    let key = market_dynamic_keys::borrow_limit_key(type_name::get<T>());

    dynamic_field::remove_if_exists<BorrowLimitKey, u64>(market_uid_mut, key);
    dynamic_field::add(market_uid_mut, key, limit_amount);
  }  

  public entry fun update_isolated_asset_status<PoolType: drop>(
    _admin_cap: &AdminCap,
    market: &mut Market,
    is_isolated: bool,
  ) {
    let market_uid_mut = market::uid_mut(market);
    let key = market_dynamic_keys::isolated_asset_key(type_name::get<PoolType>());

    dynamic_field::remove_if_exists<IsolatedAssetKey, bool>(market_uid_mut, key);
    dynamic_field::add(market_uid_mut, key, is_isolated);
  }  

  /// notice This is for admin to init the referral witness list
  /// dev Make sure only call this function once to have only 1 witness list
  public entry fun create_referral_witness_list(
    _admin_cap: &AdminCap,
    ctx: &mut TxContext
  ) {
    borrow_referral::create_witness_list(ctx);
  }

  /// notice This is for admin to authorize external referral program package
  public entry fun add_referral_witness_list<T: drop>(
    _admin_cap: &AdminCap,
    witness_list: &mut AuthorizedWitnessList
  ) {
    borrow_referral::add_witness<T>(witness_list);
  }

  /// notice This is for admin to remove the authorization of external referral program
  public entry fun remove_referral_witness_list<T: drop>(
    _admin_cap: &AdminCap,
    witness_list: &mut AuthorizedWitnessList
  ) {
    borrow_referral::remove_witness<T>(witness_list);
  }
}
