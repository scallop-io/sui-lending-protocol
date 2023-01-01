module protocol::position_collaterals {
  
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
  
  public fun init_collateral(
    collaterals: &mut WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
  ) {
    wit_table::add(PositionCollaterals{}, collaterals, typeName, Collateral{ amount: 0 });
  }
  
  public fun increase(
    collaterals: &mut WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(PositionCollaterals{}, collaterals, typeName);
    collateral.amount = collateral.amount + amount;
  }
  
  public fun decrease(
    collaterals: &mut WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(PositionCollaterals{}, collaterals, typeName);
    collateral.amount = collateral.amount - amount;
  }
  
  public fun collateral(
    collaterals: &WitTable<PositionCollaterals, TypeName, Collateral>,
    typeName: TypeName,
  ): u64 {
    let collateral = wit_table::borrow(collaterals, typeName);
    collateral.amount
  }
}
