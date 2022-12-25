module protocol::interest_model {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use math::exponential::{Self, Exp, exp};
  use x::ownership::Ownership;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  
  const EReserveFactorTooLarge: u64 = 0;
  
  struct InterestModel has store {
    baseBorrowRatePersec: Exp,
    lowSlope: Exp,
    kink: Exp,
    highSlope: Exp,
    reserveFactor: Exp,
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
    baseRatePersecEnu: u128,
    baseRatePersecDeno: u128,
    lowSlopeEnu: u128,
    lowSlopeDeno: u128,
    kinkEnu: u128,
    kinkDeno: u128,
    highSlopeEnu: u128,
    highSlopeDeno: u128,
    reserveFactorEnu: u128,
    reserveFactorDeno: u128,
  ) {
    assert!(reserveFactorEnu < reserveFactorDeno, EReserveFactorTooLarge);
    
    let baseBorrowRatePersec = exp(baseRatePersecEnu, baseRatePersecDeno);
    let lowSlope = exp(lowSlopeEnu, lowSlopeDeno);
    let kink = exp(kinkEnu, kinkDeno);
    let highSlope = exp(highSlopeEnu, highSlopeDeno);
    let reserveFactor = exp(reserveFactorEnu, reserveFactorDeno);
    let model = InterestModel {
      baseBorrowRatePersec,
      lowSlope,
      kink,
      highSlope,
      reserveFactor,
    };
    ac_table::add(interestModelTable, ownership, typeName, model)
  }
  
  public fun reserve_factor(model: &InterestModel): Exp {
    model.reserveFactor
  }
  
  public fun calc_interest(
    interestModel: &InterestModel,
    ultiRate: Exp
  ): Exp {
    let extraRate = if ( exponential::greater_than_exp(ultiRate, interestModel.kink) ) {
      let lowRate = exponential::mul_exp(interestModel.kink, interestModel.lowSlope);
      let highRate = exponential::mul_exp(
        exponential::sub_exp(ultiRate, interestModel.kink),
        interestModel.highSlope
      );
      exponential::add_exp(lowRate, highRate)
    } else {
      exponential::mul_exp(ultiRate, interestModel.lowSlope)
    };
    exponential::add_exp(interestModel.baseBorrowRatePersec, extraRate)
  }
}
