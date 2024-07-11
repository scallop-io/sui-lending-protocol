// This module is used to track the overall collateral statistics
// The real collateral balance is in each obligation's balanceBag
module protocol::collateral_stats {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use protocol::error;
  
  friend protocol::market;
  
  struct CollateralStats has drop {}
  struct CollateralStat has copy, store {
    amount: u64
  }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<CollateralStats, TypeName, CollateralStat>  {
    wit_table::new(CollateralStats{}, true, ctx)
  }
  
  public(friend) fun init_collateral_if_none(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    type_name: TypeName,
  ) {
    if (wit_table::contains(collaterals, type_name)) return;
    wit_table::add(CollateralStats{}, collaterals, type_name, CollateralStat{ amount: 0 });
  }
  
  public(friend) fun increase(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    type_name: TypeName,
    amount: u64,
  ) {
    init_collateral_if_none(collaterals, type_name);
    let collateral = wit_table::borrow_mut(CollateralStats{}, collaterals, type_name);
    collateral.amount = collateral.amount + amount;
  }
  
  public(friend) fun decrease(
    collaterals: &mut WitTable<CollateralStats, TypeName, CollateralStat>,
    type_name: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(CollateralStats{}, collaterals, type_name);
    assert!(collateral.amount >= amount, error::collateral_not_enough());
    collateral.amount = collateral.amount - amount;
  }
  
  public fun collateral_amount(
    collaterals: &WitTable<CollateralStats, TypeName, CollateralStat>,
    type_name: TypeName,
  ): u64 {
    let collateral = wit_table::borrow(collaterals, type_name);
    collateral.amount
  }
}
