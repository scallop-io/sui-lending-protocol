module mobius_protocol::interest_model {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use math::exponential::{Self ,Exp};
  use x::ownership::Ownership;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  
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
  ) {
    let model = InterestModel {
      baseBorrowRatePersec: exponential::exp(0, 1),
      lowSlope: exponential::exp(0, 1),
      kink: exponential::exp(0, 1),
      highSlope: exponential::exp(0, 1),
      reserveFactor: exponential::exp(0, 1),
    };
    ac_table::add(interestModelTable, ownership, typeName, model)
  }
  
  public fun reserve_factor(
    interestModelTable: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
  ): Exp {
    let model = ac_table::borrow(interestModelTable, typeName);
    model.reserveFactor
  }
  
  public fun calc_interest(
    interestModelTable: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
    ultiRate: Exp
  ): Exp {
    let interestModel = ac_table::borrow(interestModelTable, typeName);
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
