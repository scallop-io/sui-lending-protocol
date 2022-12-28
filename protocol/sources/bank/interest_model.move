module protocol::interest_model {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ownership::Ownership;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
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
    Ownership<AcTableOwnership>
  ) {
    ac_table::new<InterestModels, TypeName, InterestModel>(InterestModels{}, false, ctx)
  }
  
  public fun add_interest_model(
    interestModelTable: &mut AcTable<InterestModels, TypeName, InterestModel>,
    ownership: &Ownership<AcTableOwnership>,
    typeName: TypeName,
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
    ac_table::add(interestModelTable, ownership, typeName, model)
  }
  
  public fun reserve_factor(model: &InterestModel): Fr {
    model.reserveFactor
  }
  
  public fun calc_interest(
    interestModel: &InterestModel,
    ultiRate: Fr,
  ): Fr {
    let extraRate = if (fr::gt(ultiRate, interestModel.kink)) {
      let lowRate = fr::mul(interestModel.kink, interestModel.lowSlope);
      let highRate = fr::mul(
        fr::sub(ultiRate, interestModel.kink),
        interestModel.highSlope
      );
      fr::add(lowRate, highRate)
    } else {
      fr::mul(ultiRate, interestModel.lowSlope)
    };
    fr::add(interestModel.baseBorrowRatePersec, extraRate)
  }
}
