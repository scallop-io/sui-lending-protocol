/// Interest model for coin
/// TODO: implement this placeholder
module mobius_core::interest_model {
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::table::{Self, Table};
  use std::type_name::TypeName;
  use math::exponential::Exp;
  use sui::transfer;
  use math::exponential;
  
  struct InterestModel has store {
    baseBorrowRatePersec: Exp,
    lowSlope: Exp,
    kink: Exp,
    highSlope: Exp
  }
  
  struct InterestModelTable has key {
    id: UID,
    table: Table<TypeName, InterestModel>
  }
  
  fun init(ctx: &mut TxContext) {
    transfer::share_object(
      InterestModelTable {
        id: object::new(ctx),
        table: table::new(ctx)
      }
    )
  }
  
  public fun calc_interest_of_type(
    interestModelTable: &InterestModelTable,
    typeName: TypeName,
    ultiRate: Exp
  ): Exp {
    let interestModel = table::borrow(&interestModelTable.table, typeName);
    calc_interest(interestModel, ultiRate)
  }
  
  fun calc_interest(interestModel: &InterestModel, ultiRate: Exp): Exp {
    exponential::exp(0, 1)
  }
}
