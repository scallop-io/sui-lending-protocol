module protocol::obligation_collaterals {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};

  friend protocol::obligation;
  
  struct Collateral has copy, store, drop {
    amount: u64
  }
  
  struct ObligationCollaterals has drop {}
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<ObligationCollaterals, TypeName, Collateral>  {
    wit_table::new(ObligationCollaterals{}, true, ctx)
  }
  
  public(friend) fun init_collateral_if_none(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    type_name: TypeName,
  ) {
    if (wit_table::contains(collaterals, type_name)) return;
    wit_table::add(ObligationCollaterals{}, collaterals, type_name, Collateral{ amount: 0 });
  }
  
  public(friend) fun increase(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    type_name: TypeName,
    amount: u64,
  ) {
    init_collateral_if_none(collaterals, type_name);
    let collateral = wit_table::borrow_mut(ObligationCollaterals{}, collaterals, type_name);
    collateral.amount = collateral.amount + amount;
  }
  
  public(friend) fun decrease(
    collaterals: &mut WitTable<ObligationCollaterals, TypeName, Collateral>,
    type_name: TypeName,
    amount: u64,
  ) {
    let collateral = wit_table::borrow_mut(ObligationCollaterals{}, collaterals, type_name);
    collateral.amount = collateral.amount - amount;
    if (collateral.amount == 0) {
      wit_table::remove(ObligationCollaterals{}, collaterals, type_name);
    }
  }

  public(friend) fun has_coin_x_as_collateral(
    collaterals: &WitTable<ObligationCollaterals, TypeName, Collateral>,
    coin_type: TypeName,
  ): bool {
    if (wit_table::contains(collaterals, coin_type)) {
      let collateral_amount = collateral(collaterals, coin_type);
      collateral_amount > 0
    } else {
      false
    }
  }
  
  public fun collateral(
    collaterals: &WitTable<ObligationCollaterals, TypeName, Collateral>,
    type_name: TypeName,
  ): u64 {
    let collateral = wit_table::borrow(collaterals, type_name);
    collateral.amount
  }
}
