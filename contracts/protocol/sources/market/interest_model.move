module protocol::interest_model {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use math::fixed_point32_empower;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use protocol::error;

  friend protocol::app;
  friend protocol::market;

  const InterestModelChangeEffectiveEpoches: u64 = 7;
  
  struct InterestModel has copy, store, drop {
    type: TypeName,
    base_borrow_rate_per_sec: FixedPoint32,
    interest_rate_scale: u64,
    low_slope: FixedPoint32,
    mid_kink: FixedPoint32,
    mid_slope: FixedPoint32,
    high_kink: FixedPoint32,
    high_slope: FixedPoint32,
    revenue_factor: FixedPoint32,
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    min_borrow_amount: u64,
    borrow_weight: FixedPoint32,
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

  public fun base_borrow_rate(model: &InterestModel): FixedPoint32 { model.base_borrow_rate_per_sec }
  public fun interest_rate_scale(model: &InterestModel): u64 { model.interest_rate_scale }
  public fun low_slope(model: &InterestModel): FixedPoint32 { model.low_slope }
  public fun mid_kink(model: &InterestModel): FixedPoint32 { model.mid_kink }
  public fun mid_slope(model: &InterestModel): FixedPoint32 { model.mid_slope }
  public fun high_kink(model: &InterestModel): FixedPoint32 { model.high_kink }
  public fun high_slope(model: &InterestModel): FixedPoint32 { model.high_slope }
  public fun revenue_factor(model: &InterestModel): FixedPoint32 { model.revenue_factor }
  public fun min_borrow_amount(model: &InterestModel): u64 { model.min_borrow_amount }
  public fun type_name(model: &InterestModel): TypeName { model.type }
  public fun borrow_weight(model: &InterestModel): FixedPoint32 { model.borrow_weight }
  
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
    low_slope: u64,
    mid_kink: u64,
    mid_slope: u64,
    high_kink: u64,
    high_slope: u64,
    revenue_factor: u64,
    scale: u64,
    min_borrow_amount: u64,
    borrow_weight: u64,
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let base_borrow_rate_per_sec = fixed_point32::create_from_rational(base_rate_per_sec, scale);
    let low_slope = fixed_point32::create_from_rational(low_slope, scale);
    let mid_kink = fixed_point32::create_from_rational(mid_kink, scale);
    let mid_slope = fixed_point32::create_from_rational(mid_slope, scale);
    let high_kink = fixed_point32::create_from_rational(high_kink, scale);
    let high_slope = fixed_point32::create_from_rational(high_slope, scale);
    let revenue_factor = fixed_point32::create_from_rational(revenue_factor, scale);
    let borrow_weight = fixed_point32::create_from_rational(borrow_weight, scale);
    let interest_model = InterestModel {
      type: get<T>(),
      base_borrow_rate_per_sec,
      interest_rate_scale,
      low_slope,
      mid_kink,
      mid_slope,
      high_kink,
      high_slope,
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

    let type_name = get<T>();
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
    util_rate: FixedPoint32,
  ): (FixedPoint32, u64) {
    let interest_rate_scale = interest_model.interest_rate_scale;
    let low_slope = interest_model.low_slope;
    let mid_kink = interest_model.mid_kink;
    let mid_slope = interest_model.mid_slope;
    let high_kink = interest_model.high_kink;
    let high_slope = interest_model.high_slope;
    let base_rate = interest_model.base_borrow_rate_per_sec;
    /*****************
    Calculate the interest rate with the given utlilization rate of the pool
    if ultiRate > high_kink:
      interestRate = baseRate * (1 + mid_kink * low_scope + (high_kink - mid_kink) * mid_scope + (util_rate - high_kink) * high_slope)
    else if ultiRate > mid_kink:
      interestRate = baseRate * (1 + mid_kink * low_scope + (util_rate - mid_kink) * mid_scope)
    else:
      interestRate = baseRate * (1 + util_rate * low_scope)
    ******************/
    let rate_growth = if (fixed_point32_empower::gt(util_rate, high_kink)) {
      let first_part = fixed_point32_empower::add(
        fixed_point32_empower::mul(mid_kink, low_slope),
        fixed_point32_empower::mul(fixed_point32_empower::sub(high_kink, mid_kink), mid_slope)
      );
      fixed_point32_empower::add(
        first_part,
        fixed_point32_empower::mul(fixed_point32_empower::sub(util_rate, high_kink), high_slope)
      )
    } else if (fixed_point32_empower::gt(util_rate, mid_kink)) {
      fixed_point32_empower::add(
        fixed_point32_empower::mul(mid_kink, low_slope),
        fixed_point32_empower::mul(fixed_point32_empower::sub(util_rate, mid_kink), mid_slope)
      )
    } else {
      fixed_point32_empower::mul(util_rate, low_slope)
    };
    (
      fixed_point32_empower::mul(
        base_rate,
        fixed_point32_empower::add(fixed_point32::create_from_rational(1, 1), rate_growth)
      ),
      interest_rate_scale,
    )
  }
}
