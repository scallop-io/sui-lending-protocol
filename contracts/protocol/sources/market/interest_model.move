module protocol::interest_model {
  
  use std::type_name::{Self, TypeName};
  use std::uq32_32::{Self, UQ32_32};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use math::UQ32_32_empower;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use protocol::error;

  friend protocol::app;
  friend protocol::market;

  const InterestModelChangeEffectiveEpoches: u64 = 7;
  const MAX_REASONABLE_BORROW_RATE: u64 = 1000; // 1000%
  const MAX_REASONABLE_BORROW_WEIGHT: u64 = 500; // 500%
  const MIN_REASONABLE_BORROW_WEIGHT: u64 = 100; // 100%

  struct InterestModel has copy, store, drop {
    type: TypeName,
    base_borrow_rate_per_sec: UQ32_32,
    interest_rate_scale: u64,
    borrow_rate_on_mid_kink: UQ32_32,
    mid_kink: UQ32_32,
    borrow_rate_on_high_kink: UQ32_32,
    high_kink: UQ32_32,
    max_borrow_rate: UQ32_32,
    revenue_factor: UQ32_32,
    borrow_weight: UQ32_32,
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    min_borrow_amount: u64,
  }

  struct InterestModelChangeCreated has copy, drop {
    interest_model: InterestModel,
    current_epoch: u64, // the epoch when the change is created
    delay_epoches: u64, // the delay epoches before the change takes effect
    effective_epoches: u64, // the epoch when the change takes effect
  }

  struct InterestModelAdded has copy, drop {
    interest_model: InterestModel,
    current_epoch: u64, // the epoch when the interest model is updated
  }

  public fun base_borrow_rate(model: &InterestModel): UQ32_32 { model.base_borrow_rate_per_sec }
  public fun interest_rate_scale(model: &InterestModel): u64 { model.interest_rate_scale }
  public fun borrow_rate_on_mid_kink(model: &InterestModel): UQ32_32 { model.borrow_rate_on_mid_kink }
  public fun mid_kink(model: &InterestModel): UQ32_32 { model.mid_kink }
  public fun borrow_rate_on_high_kink(model: &InterestModel): UQ32_32 { model.borrow_rate_on_high_kink }
  public fun high_kink(model: &InterestModel): UQ32_32 { model.high_kink }
  public fun max_borrow_rate(model: &InterestModel): UQ32_32 { model.max_borrow_rate }
  public fun revenue_factor(model: &InterestModel): UQ32_32 { model.revenue_factor }
  public fun borrow_weight(model: &InterestModel): UQ32_32 { model.borrow_weight }
  public fun min_borrow_amount(model: &InterestModel): u64 { model.min_borrow_amount }
  public fun type_name(model: &InterestModel): TypeName { model.type }

  struct InterestModels has drop {}
  
  public(friend) fun new(ctx: &mut TxContext): (
    AcTable<InterestModels, TypeName, InterestModel>,
    AcTableCap<InterestModels>,
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, true, ctx)
  }
  
  public(friend) fun create_interest_model_change<T>(
    _: &AcTableCap<InterestModels>,
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
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    // mid_kink should be < high_kink, and can't be equal
    assert!(mid_kink < high_kink, error::interest_model_param_error());
    // high_kink must be < 100%
    assert!(high_kink < scale, error::interest_model_param_error());
    // mid_kink should be > 0
    assert!(mid_kink > 0, error::interest_model_param_error());

    // max_borrow_rate should be within reasonable number
    assert!(
      UQ32_32_empower::gte(
        uq32_32::from_quotient(MAX_REASONABLE_BORROW_RATE, 100),
        uq32_32::from_quotient(max_borrow_rate, scale),
      ),
      error::interest_model_param_error()
    );

    // borrow_weight should be within reasonable number, max 5, minimum 1
    assert!(
      UQ32_32_empower::gte(
        uq32_32::from_quotient(MAX_REASONABLE_BORROW_WEIGHT, 100),
        uq32_32::from_quotient(borrow_weight, scale),
      ),
      error::interest_model_param_error()
    );
    assert!(
      UQ32_32_empower::gte(
        uq32_32::from_quotient(borrow_weight, scale),
        uq32_32::from_quotient(MIN_REASONABLE_BORROW_WEIGHT, 100),
      ),
      error::interest_model_param_error()
    );

    assert!(base_rate_per_sec <= borrow_rate_on_mid_kink, error::interest_model_param_error());
    assert!(borrow_rate_on_mid_kink <= borrow_rate_on_high_kink, error::interest_model_param_error());
    assert!(borrow_rate_on_high_kink <= max_borrow_rate, error::interest_model_param_error());
    // revenue factor is the portion of interest that goes to the protocol, so it must be <= 100%
    assert!(revenue_factor <= scale, error::interest_model_param_error());

    let base_borrow_rate_per_sec = uq32_32::from_quotient(base_rate_per_sec, scale);
    let borrow_rate_on_mid_kink = uq32_32::from_quotient(borrow_rate_on_mid_kink, scale);
    let mid_kink = uq32_32::from_quotient(mid_kink, scale);
    let borrow_rate_on_high_kink = uq32_32::from_quotient(borrow_rate_on_high_kink, scale);
    let high_kink = uq32_32::from_quotient(high_kink, scale);
    let max_borrow_rate = uq32_32::from_quotient(max_borrow_rate, scale);
    let revenue_factor = uq32_32::from_quotient(revenue_factor, scale);
    let borrow_weight = uq32_32::from_quotient(borrow_weight, scale);
    let interest_model = InterestModel {
      type: type_name::with_defining_ids<T>(),
      base_borrow_rate_per_sec,
      interest_rate_scale,
      borrow_rate_on_mid_kink,
      mid_kink,
      borrow_rate_on_high_kink,
      high_kink,
      max_borrow_rate,
      revenue_factor,
      min_borrow_amount,
      borrow_weight,
    };
    emit(InterestModelChangeCreated{
      interest_model,
      current_epoch: tx_context::epoch(ctx),
      delay_epoches: change_delay,
      effective_epoches: tx_context::epoch(ctx) + change_delay
    });
    one_time_lock_value::new(interest_model, change_delay, InterestModelChangeEffectiveEpoches, ctx)
  }
  
  public(friend) fun add_interest_model<T>(
    interest_model_table: &mut AcTable<InterestModels, TypeName, InterestModel>,
    cap: &AcTableCap<InterestModels>,
    interest_model_change: OneTimeLockValue<InterestModel>,
    ctx: &mut TxContext,
  ) {
    let interest_model = one_time_lock_value::get_value(interest_model_change, ctx);

    let type_name = type_name::with_defining_ids<T>();
    assert!(interest_model.type == type_name, error::interest_model_type_not_match_error());

    // Remove the old interest model if exists
    if (ac_table::contains(interest_model_table, type_name)) {
      ac_table::remove(interest_model_table, cap, type_name);
    };
    // Add the new interest model
    ac_table::add(interest_model_table, cap, type_name, interest_model);
    emit(InterestModelAdded{
      interest_model,
      current_epoch: tx_context::epoch(ctx),
    });
  }

  // Return the interest rate under the given utilization rate
  // Notice: the interest rate is scaled by a factor, because it's too small to be used directly
  public fun calc_interest(
    interest_model: &InterestModel,
    util_rate: UQ32_32,
  ): (UQ32_32, u64) {
    let interest_rate_scale = interest_model.interest_rate_scale;
    let borrow_rate_on_mid_kink = interest_model.borrow_rate_on_mid_kink;
    let mid_kink = interest_model.mid_kink;
    let borrow_rate_on_high_kink = interest_model.borrow_rate_on_high_kink;
    let high_kink = interest_model.high_kink;
    let max_borrow_rate = interest_model.max_borrow_rate;
    let base_rate = interest_model.base_borrow_rate_per_sec;
    /* ================== Interest Rate Formula ==================

    Calculate the interest rate with the given utlilization rate of the pool
    if util_rate <= mid_kink:
      interest_rate = (util_rate / mid_kink) * (borrow_rate_on_mid_kink - base_rate) + base_rate
    else if util_rate <= high_kink:
      interest_rate = ((util_rate - mid_kink) / (high_kink - mid_kink)) * (borrow_rate_on_high_kink - borrow_rate_on_mid_kink) + borrow_rate_on_mid_kink
    else:
      interest_rate = ((util_rate - high_kink) / (1 - high_kink)) * (max_borrow_rate - borrow_rate_on_high_kink) + borrow_rate_on_high_kink

    ============================================================== */
    // util_rate must be <= 100%
    assert!(UQ32_32_empower::gte(UQ32_32_empower::from_u64(1), util_rate), error::invalid_util_rate_error());

    let borrow_rate = if (UQ32_32_empower::gte(mid_kink, util_rate)) {
      let weight = UQ32_32_empower::div(util_rate, mid_kink);
      let range = UQ32_32_empower::sub(borrow_rate_on_mid_kink, base_rate);
      
      UQ32_32_empower::add(
        // `weight` is like how far it goes from the starting point within the `range`
        UQ32_32_empower::mul(weight, range),
        // base borrow rate is the starting point
        base_rate
      )
    } else if (UQ32_32_empower::gte(high_kink, util_rate)) {
      let weight = UQ32_32_empower::div(
        UQ32_32_empower::sub(util_rate, mid_kink),
        UQ32_32_empower::sub(high_kink, mid_kink)
      );
      let range = UQ32_32_empower::sub(borrow_rate_on_high_kink, borrow_rate_on_mid_kink);

      UQ32_32_empower::add(
        UQ32_32_empower::mul(weight, range),
        borrow_rate_on_mid_kink
      )
    } else {
      let weight = UQ32_32_empower::div(
        UQ32_32_empower::sub(util_rate, high_kink),
        UQ32_32_empower::sub(UQ32_32_empower::from_u64(1), high_kink)
      );
      let range = UQ32_32_empower::sub(max_borrow_rate, borrow_rate_on_high_kink);

      UQ32_32_empower::add(
        UQ32_32_empower::mul(weight, range),
        borrow_rate_on_high_kink
      )
    };

    (borrow_rate, interest_rate_scale)
  }

  #[test_only]
  struct USDC has drop {}

  #[test_only]
  use std::type_name;

  #[test]
  fun interest_rates_test() {
    let interest_model = InterestModel {
      type: type_name::  with_defining_ids<USDC>(),
      // this borrow rate is not for every sec, cause it just for testing
      base_borrow_rate_per_sec: uq32_32::from_quotient(2, 100),
      interest_rate_scale: 1,
      borrow_rate_on_mid_kink: uq32_32::from_quotient(10, 100),
      mid_kink: uq32_32::from_quotient(40, 100),
      borrow_rate_on_high_kink: uq32_32::from_quotient(50, 100),
      high_kink: uq32_32::from_quotient(80, 100),
      max_borrow_rate: uq32_32::from_quotient(120, 100),
      revenue_factor: uq32_32::from_quotient(5, 100), // in this case, it will be ignored anyway
      min_borrow_amount: 1000, // in this case, it will be ignored anyway
      borrow_weight: uq32_32::from_quotient(1, 1), // in this case, it will be ignored anyway
    };
    
    // === Low Demand
    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(10, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 3, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(40, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 9, 0);

    // === Optimal Demand
    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(41, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 10, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(50, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 19, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(60, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 29, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(70, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 39, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(80, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 50, 0);
    
    // === High Demand
    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(85, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 67, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(90, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 84, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(95, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 102, 0);

    let (borrow_rate, _) = calc_interest(
      &interest_model, uq32_32::from_quotient(100, 100)
    );
    assert!(shift_decimal(borrow_rate, 2) == 119, 0);
  }

  #[test_only]
  fun shift_decimal(number: UQ32_32, number_of_shift: u8): u64 {
    use sui::math;
    uq32_32::int_mul(std::u64::pow(10, number_of_shift), number)
  }
}
