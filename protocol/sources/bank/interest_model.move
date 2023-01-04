module protocol::interest_model {
  
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use math::fr::{Self, fr, Fr};
  use x::one_time_lock_value::OneTimeLockValue;
  use x::one_time_lock_value;
  
  const InterestChangeDelay: u64 = 11;
  
  const EReserveFactorTooLarge: u64 = 0;
  const EInterestModelChangeConsumed: u64 = 1;
  const EInterestModelChangePending: u64 = 1;
  
  struct InterestModel has copy, store {
    type: TypeName,
    baseBorrowRatePerSec: Fr,
    lowSlope: Fr,
    kink: Fr,
    highSlope: Fr,
    reserveFactor: Fr,
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    // TODO: put this field somewhere else, it's not meant to be in interest model
    minBorrowAmount: u64,
  }
  public fun base_borrow_rate(model: &InterestModel): Fr { model.baseBorrowRatePerSec }
  public fun low_slope(model: &InterestModel): Fr { model.lowSlope }
  public fun kink(model: &InterestModel): Fr { model.kink }
  public fun high_slope(model: &InterestModel): Fr { model.highSlope }
  public fun reserve_factor(model: &InterestModel): Fr { model.reserveFactor }
  public fun min_borrow_amount(model: &InterestModel): u64 { model.minBorrowAmount }
  
  
  struct InterestModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<InterestModels, TypeName, InterestModel>,
    AcTableCap<InterestModels>,
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, false, ctx)
  }
  
  public fun create_interest_model_change<T>(
    _: &AcTableCap<InterestModels>,
    baseRatePerSec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64,
    reserveFactor: u64,
    scale: u64,
    minBorrowAmount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<InterestModel> {
    let baseBorrowRatePerSec = fr(baseRatePerSec, scale);
    let lowSlope = fr(lowSlope, scale);
    let kink = fr(kink, scale);
    let highSlope = fr(highSlope, scale);
    let reserveFactor = fr(reserveFactor, scale);
    let interestModel = InterestModel {
      type: get<T>(),
      baseBorrowRatePerSec,
      lowSlope,
      kink,
      highSlope,
      reserveFactor,
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
    ac_table::add(interestModelTable, cap, get<T>(), interestModel)
  }
  
  public fun calc_interest(
    interestModel: &InterestModel,
    ultiRate: Fr,
  ): Fr {
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
    let rateGrowth = if (fr::gt(ultiRate, kink)) {
      fr::add(
        fr::mul(kink, lowSlope),
        fr::mul(fr::sub(ultiRate, kink), highSlope)
      )
    } else {
      fr::mul(ultiRate, lowSlope)
    };
    fr::mul(baseRate, fr::add(fr::int(1), rateGrowth))
  }
}
