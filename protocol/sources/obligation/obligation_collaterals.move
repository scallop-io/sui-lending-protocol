module protocol::obligation_collaterals {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  
  struct Collateral has copy, store {
    amount: u64
  }
  
  struct ObligationCollaterals has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<ObligationCollaterals, TypeName, Collateral>  {
    wit_table::new(ObligationCollaterals{}, true, ctx)
  }
  
  public fun init_collateral_if_none(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    typeName: TypeName,
  ) {
    if (wit_table::contains(collaterals, typeName)) return;
    wit_table::add(ObligationCollaterals{}, collaterals, typeName, Collateral{ amount: 0 });
  }
  
  public fun increase(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    typeName: TypeName,
    amount: u64,
  ) {
    init_collateral_if_none(collaterals, typeName);
    let collateral = wit_table::borrow_mut(ObligationCollaterals{}, collaterals, typeName);
    collateral.amount = collateral.amount + amount;
  }
  
  public fun decrease(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    typeName: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(ObligationCollaterals{}, collaterals, typeName);
    collateral.amount = collateral.amount - amount;
  }
  
  public fun collateral(
    collaterals: &WitTable<ObligationCollaterals, TypeName, Collateral>,
    typeName: TypeName,
  ): u64 {
    let collateral = wit_table::borrow(collaterals, typeName);
    collateral.amount
  }
}
