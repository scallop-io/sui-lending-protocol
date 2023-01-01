module protocol::interest_model {
  
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use math::fr::{Self, fr, Fr};
  
  const EReserveFactorTooLarge: u64 = 0;
  
  struct InterestModel has store {
    baseBorrowRatePersec: Fr,
    lowSlope: Fr,
    kink: Fr,
    highSlope: Fr,
    reserveFactor: Fr,
  }
  
  struct InterestModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<InterestModels, TypeName, InterestModel>,
    AcTableCap<InterestModels>,
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, false, ctx)
  }
  
  public fun add_interest_model<T>(
    interestModelTable: &mut AcTable<InterestModels, TypeName, InterestModel>,
    cap: &AcTableCap<InterestModels>,
    baseRatePersecEnu: u64,
    baseRatePersecDeno: u64,
    lowSlopeEnu: u64,
    lowSlopeDeno: u64,
    kinkEnu: u64,
    kinkDeno: u64,
    highSlopeEnu: u64,
    highSlopeDeno: u64,
    reserveFactorEnu: u64,
    reserveFactorDeno: u64,
  ) {
    assert!(reserveFactorEnu < reserveFactorDeno, EReserveFactorTooLarge);
    
    let baseBorrowRatePersec = fr(baseRatePersecEnu, baseRatePersecDeno);
    let lowSlope = fr(lowSlopeEnu, lowSlopeDeno);
    let kink = fr(kinkEnu, kinkDeno);
    let highSlope = fr(highSlopeEnu, highSlopeDeno);
    let reserveFactor = fr(reserveFactorEnu, reserveFactorDeno);
    let model = InterestModel {
      baseBorrowRatePersec,
      lowSlope,
      kink,
      highSlope,
      reserveFactor,
    };
    ac_table::add(interestModelTable, cap, get<T>(), model)
  }
  
  public fun reserve_factor(model: &InterestModel): Fr {
    model.reserveFactor
  }
  
  public fun calc_interest(
    interestModel: &InterestModel,
    ultiRate: Fr,
  ): Fr {
    let lowSlope = interestModel.lowSlope;
    let highSlope = interestModel.highSlope;
    let kink = interestModel.kink;
    let baseRate = interestModel.baseBorrowRatePersec;
    /*****************
    Calculate the interest rate with the given utlilization rate of the pool
    When ultiRate > kink:
      interestRate = baseRate + kink * lowScope + (ultiRate - kink) * highScope
    When ultiRate <= kink:
      interestRate = baseRate + ultiRate * lowScope
    ******************/
    let extraRate = if (fr::gt(ultiRate, kink)) {
      fr::add(
        fr::mul(kink, lowSlope),
        fr::mul(fr::sub(ultiRate, kink), highSlope)
      )
    } else {
      fr::mul(ultiRate, lowSlope)
    };
    fr::add(baseRate, extraRate)
  }
}
