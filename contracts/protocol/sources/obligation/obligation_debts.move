module protocol::obligation_debts {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use std::fixed_point32;

  friend protocol::obligation;

  struct Debt has copy, store {
    amount: u64,
    borrow_index: u64
  }
  
  struct ObligationDebts has drop {}
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<ObligationDebts, TypeName, Debt> {
    wit_table::new(ObligationDebts{}, true, ctx)
  }
  
  public(friend) fun init_debt(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    type_name: TypeName,
    borrow_index: u64,
  ) {
    if (wit_table::contains(debts, type_name)) return;
    let debt = Debt { amount: 0, borrow_index };
    wit_table::add(ObligationDebts{}, debts, type_name, debt);
  }
  
  public(friend) fun increase(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    type_name: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, type_name);
    debt.amount = debt.amount + amount;
  }
  
  public(friend) fun decrease(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    type_name: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, type_name);
    debt.amount = debt.amount - amount;
  }
  
  public(friend) fun accure_interest(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    type_name: TypeName,
    new_borrow_index: u64
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, type_name);
    debt.amount = fixed_point32::multiply_u64(debt.amount, fixed_point32::create_from_rational(new_borrow_index, debt.borrow_index));
    debt.borrow_index = new_borrow_index;
  }
  
  public fun debt(
    debts: &WitTable<ObligationDebts, TypeName, Debt>,
    type_name: TypeName,
  ): (u64, u64) {
    let debt = wit_table::borrow(debts, type_name);
    (debt.amount, debt.borrow_index)
  }
}
