module protocol::obligation_debts {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use std::fixed_point32;

  struct Debt has copy, store {
    amount: u64,
    borrowIndex: u64
  }
  
  struct ObligationDebts has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<ObligationDebts, TypeName, Debt> {
    wit_table::new(ObligationDebts{}, true, ctx)
  }
  
  public fun init_debt(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    typeName: TypeName,
    borrowIndex: u64,
  ) {
    if (wit_table::contains(debts, typeName)) return;
    let debt = Debt { amount: 0, borrowIndex };
    wit_table::add(ObligationDebts{}, debts, typeName, debt);
  }
  
  public fun increase(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    typeName: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, typeName);
    debt.amount = debt.amount + amount;
  }
  
  public fun decrease(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    typeName: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, typeName);
    debt.amount = debt.amount - amount;
  }
  
  public fun accure_interest(
    debts: &mut WitTable<ObligationDebts, TypeName, Debt>,
    typeName: TypeName,
    newBorrowIndex: u64
  ) {
    let debt = wit_table::borrow_mut(ObligationDebts{}, debts, typeName);
    debt.amount = fixed_point32::multiply_u64(debt.amount, fixed_point32::create_from_rational(newBorrowIndex, debt.borrowIndex));
    debt.borrowIndex = newBorrowIndex;
  }
  
  public fun debt(
    debts: &WitTable<ObligationDebts, TypeName, Debt>,
    typeName: TypeName,
  ): (u64, u64) {
    let debt = wit_table::borrow(debts, typeName);
    (debt.amount, debt.borrowIndex)
  }
}
