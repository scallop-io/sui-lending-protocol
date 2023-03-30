module protocol::interest_model {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use math::fixed_point32_empower;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  
  const InterestChangeDelay: u64 = 7;
  
  const ERevenueFactorTooLarge: u64 = 0;
  const EInterestModelTypeNotMatch: u64 = 1;
  
  struct InterestModel has copy, store {
    type: TypeName,
    baseBorrowRatePerSec: FixedPoint32,
    lowSlope: FixedPoint32,
    kink: FixedPoint32,
    highSlope: FixedPoint32,
    revenueFactor: FixedPoint32,
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    minBorrowAmount: u64,
  }
  public fun base_borrow_rate(model: &InterestModel): FixedPoint32 { model.baseBorrowRatePerSec }
  public fun low_slope(model: &InterestModel): FixedPoint32 { model.lowSlope }
  public fun kink(model: &InterestModel): FixedPoint32 { model.kink }
  public fun high_slope(model: &InterestModel): FixedPoint32 { model.highSlope }
  public fun revenue_factor(model: &InterestModel): FixedPoint32 { model.revenueFactor }
  public fun min_borrow_amount(model: &InterestModel): u64 { model.minBorrowAmount }
  
  struct InterestModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<InterestModels, TypeName, InterestModel>,
    AcTableCap<InterestModels>,
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, true, ctx)
  }
  
  public fun create_interest_model_change<T>(
    _: &AcTableCap<InterestModels>,
    baseRatePerSec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64,
    revenueFactor: u64,
    scale: u64,
    minBorrowAmount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let baseBorrowRatePerSec = fixed_point32::create_from_rational(baseRatePerSec, scale);
    let lowSlope = fixed_point32::create_from_rational(lowSlope, scale);
    let kink = fixed_point32::create_from_rational(kink, scale);
    let highSlope = fixed_point32::create_from_rational(highSlope, scale);
    let revenueFactor = fixed_point32::create_from_rational(revenueFactor, scale);
    let interestModel = InterestModel {
      type: get<T>(),
      baseBorrowRatePerSec,
      lowSlope,
      kink,
      highSlope,
      revenueFactor,
      minBorrowAmount
    };
    one_time_lock_value::new(interestModel, InterestChangeDelay, 7, ctx)
  }
  
  public fun add_interest_model<T>(
    interestModelTable: &mut AcTable<InterestModels, TypeName, InterestModel>,
    cap: &AcTableCap<InterestModels>,
    interestModelChange: &mut OneTimeLockValue<InterestModel>,
    ctx: &mut TxContext,
  ) {
    let interestModel = one_time_lock_value::get_value(interestModelChange, ctx);
    let typeName = get<T>();
    assert!(interestModel.type == typeName, EInterestModelTypeNotMatch);
    ac_table::add(interestModelTable, cap, typeName, interestModel)
  }
  
  public fun calc_interest(
    interestModel: &InterestModel,
    ultiRate: FixedPoint32,
  ): FixedPoint32 {
    let lowSlope = interestModel.lowSlope;
    let highSlope = interestModel.highSlope;
    let kink = interestModel.kink;
    let baseRate = interestModel.baseBorrowRatePerSec;
    /*****************
    Calculate the interest rate with the given utlilization rate of the pool
    When ultiRate > kink:
      interestRate = baseRate(1 + kink * lowScope + (ultiRate - kink) * highScope)
    When ultiRate <= kink:
      interestRate = baseRate(1 + ultiRate * lowScope)
    ******************/
    let rateGrowth = if (fixed_point32_empower::gt(ultiRate, kink)) {
      fixed_point32_empower::add(
        fixed_point32_empower::mul(kink, lowSlope),
        fixed_point32_empower::mul(fixed_point32_empower::sub(ultiRate, kink), highSlope)
      )
    } else {
      fixed_point32_empower::mul(ultiRate, lowSlope)
    };
    fixed_point32_empower::mul(
      baseRate,
      fixed_point32_empower::add(fixed_point32::create_from_rational(1, 1), rateGrowth)
    )
  }
}
