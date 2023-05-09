module protocol::interest_model {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use math::fixed_point32_empower;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};

  // TODO: change it to a bgger value when launch on mainnet
  const InterestChangeDelay: u64 = 0;
  
  const ERevenueFactorTooLarge: u64 = 0;
  const EInterestModelTypeNotMatch: u64 = 1;
  
  struct InterestModel has copy, store, drop {
    type: TypeName,
    base_borrow_rate_per_sec: FixedPoint32,
    low_slope: FixedPoint32,
    kink: FixedPoint32,
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
  public fun base_borrow_rate(model: &InterestModel): FixedPoint32 { model.base_borrow_rate_per_sec }
  public fun low_slope(model: &InterestModel): FixedPoint32 { model.low_slope }
  public fun kink(model: &InterestModel): FixedPoint32 { model.kink }
  public fun high_slope(model: &InterestModel): FixedPoint32 { model.high_slope }
  public fun revenue_factor(model: &InterestModel): FixedPoint32 { model.revenue_factor }
  public fun min_borrow_amount(model: &InterestModel): u64 { model.min_borrow_amount }
  public fun type_name(model: &InterestModel): TypeName { model.type }
  public fun borrow_weight(model: &InterestModel): FixedPoint32 { model.borrow_weight }
  
  struct InterestModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<InterestModels, TypeName, InterestModel>,
    AcTableCap<InterestModels>,
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, true, ctx)
  }
  
  public fun create_interest_model_change<T>(
    _: &AcTableCap<InterestModels>,
    base_rate_per_sec: u64,
    low_slope: u64,
    kink: u64,
    high_slope: u64,
    revenue_factor: u64,
    scale: u64,
    min_borrow_amount: u64,
    borrow_weight: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let base_borrow_rate_per_sec = fixed_point32::create_from_rational(base_rate_per_sec, scale);
    let low_slope = fixed_point32::create_from_rational(low_slope, scale);
    let kink = fixed_point32::create_from_rational(kink, scale);
    let high_slope = fixed_point32::create_from_rational(high_slope, scale);
    let revenue_factor = fixed_point32::create_from_rational(revenue_factor, scale);
    let borrow_weight = fixed_point32::create_from_rational(borrow_weight, scale);
    let interest_model = InterestModel {
      type: get<T>(),
      base_borrow_rate_per_sec,
      low_slope,
      kink,
      high_slope,
      revenue_factor,
      min_borrow_amount,
      borrow_weight,
    };
    one_time_lock_value::new(interest_model, InterestChangeDelay, 7, ctx)
  }
  
  public fun add_interest_model<T>(
    interestModelTable: &mut AcTable<InterestModels, TypeName, InterestModel>,
    cap: &AcTableCap<InterestModels>,
    interestModelChange: OneTimeLockValue<InterestModel>,
    ctx: &mut TxContext,
  ) {
    let interestModel = one_time_lock_value::get_value(interestModelChange, ctx);
    let typeName = get<T>();
    assert!(interestModel.type == typeName, EInterestModelTypeNotMatch);
    ac_table::add(interestModelTable, cap, typeName, interestModel)
  }
  
  public fun calc_interest(
    interest_model: &InterestModel,
    ulti_rate: FixedPoint32,
  ): FixedPoint32 {
    let low_slope = interest_model.low_slope;
    let high_slope = interest_model.high_slope;
    let kink = interest_model.kink;
    let base_rate = interest_model.base_borrow_rate_per_sec;
    /*****************
    Calculate the interest rate with the given utlilization rate of the pool
    When ultiRate > kink:
      interestRate = baseRate(1 + kink * lowScope + (ultiRate - kink) * highScope)
    When ultiRate <= kink:
      interestRate = baseRate(1 + ultiRate * lowScope)
    ******************/
    let rate_growth = if (fixed_point32_empower::gt(ulti_rate, kink)) {
      fixed_point32_empower::add(
        fixed_point32_empower::mul(kink, low_slope),
        fixed_point32_empower::mul(fixed_point32_empower::sub(ulti_rate, kink), high_slope)
      )
    } else {
      fixed_point32_empower::mul(ulti_rate, low_slope)
    };
    fixed_point32_empower::mul(
      base_rate,
      fixed_point32_empower::add(fixed_point32::create_from_rational(1, 1), rate_growth)
    )
  }
}
