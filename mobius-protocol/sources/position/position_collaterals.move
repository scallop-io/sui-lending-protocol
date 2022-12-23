module mobius_protocol::position_collaterals {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  
  struct Collateral has store {
    amount: u64
  }
  
  struct PositionCollaterals has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<PositionCollaterals, TypeName, Collateral>  {
    wit_table::new(PositionCollaterals{}, true, ctx)
  }
  
  public fun update_collateral(
    collaterals: &mut WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
    amount: u64,
  ) {
    if (wit_table::contains(collaterals, typeName)) {
      let collateral = wit_table::borrow_mut(PositionCollaterals{}, collaterals, typeName);
      collateral.amount = amount;
    } else {
      let collateral = Collateral { amount };
      wit_table::add(PositionCollaterals{}, collaterals, typeName, collateral);
    }
  }
  
  public fun collateral(
    collaterals: &WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
  ): u64 {
    
    let collateral = wit_table::borrow(collaterals, typeName);
    collateral.amount
  }
}
