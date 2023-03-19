// This module is used to track the overall collateral statistics
// The real collateral balance is in each obligation's balanceBag
module protocol::collateral_stats {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  
  friend protocol::reserve;
  
  struct CollateralStats has drop {}
  struct CollateralStat has copy, store {
    amount: u64
  }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<CollateralStats, TypeName, CollateralStat>  {
    wit_table::new(CollateralStats{}, true, ctx)
  }
  
  public(friend) fun init_collateral_if_none(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    typeName: TypeName,
  ) {
    if (wit_table::contains(collaterals, typeName)) return;
    wit_table::add(CollateralStats{}, collaterals, typeName, CollateralStat{ amount: 0 });
  }
  
  public(friend) fun increase(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    typeName: TypeName,
    amount: u64,
  ) {
    init_collateral_if_none(collaterals, typeName);
    let collateral = wit_table::borrow_mut(CollateralStats{}, collaterals, typeName);
    collateral.amount = collateral.amount + amount;
  }
  
  public(friend) fun decrease(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    typeName: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(CollateralStats{}, collaterals, typeName);
    collateral.amount = collateral.amount - amount;
  }
  
  public fun collateral_amount(
    collaterals: &WitTable<CollateralStats, TypeName, CollateralStat>,
    typeName: TypeName,
  ): u64 {
    let collateral = wit_table::borrow(collaterals, typeName);
    collateral.amount
  }
}
