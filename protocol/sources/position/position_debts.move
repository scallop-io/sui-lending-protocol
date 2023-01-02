module protocol::position_debts {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use math::fr;
  use math::mix;
  
  struct Debt has store {
    amount: u64,
    borrowIndex: u64
  }
  
  struct PositionDebts has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<PositionDebts, TypeName, Debt> {
    wit_table::new(PositionDebts{}, true, ctx)
  }
  
  public fun init_debt(
    debts: &mut WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
    borrowIndex: u64,
  ) {
    if (wit_table::contains(debts, typeName)) return;
    let debt = Debt { amount: 0, borrowIndex };
    wit_table::add(PositionDebts{}, debts, typeName, debt);
  }
  
  public fun increase(
    debts: &mut WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(PositionDebts{}, debts, typeName);
    debt.amount = debt.amount + amount;
  }
  
  public fun decrease(
    debts: &mut WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
    amount: u64,
  ) {
    let debt = wit_table::borrow_mut(PositionDebts{}, debts, typeName);
    debt.amount = debt.amount - amount;
  }
  
  public fun accure_interest(
    debts: &mut WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
    newBorrowIndex: u64
  ) {
    let debt = wit_table::borrow_mut(PositionDebts{}, debts, typeName);
    debt.amount = mix::mul_ifrT(debt.amount, fr::fr(newBorrowIndex, debt.borrowIndex));
    debt.borrowIndex = newBorrowIndex;
  }
  
  public fun debt(
    debts: &WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
  ): (u64, u64) {
    let debt = wit_table::borrow(debts, typeName);
    (debt.amount, debt.borrowIndex)
  }
}
