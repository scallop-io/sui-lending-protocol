module protocol::position_debts {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use math::exponential::Exp;
  
  struct Debt has store {
    amount: u64,
    borrowMark: Exp
  }
  
  struct PositionDebts has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<PositionDebts, TypeName, Debt> {
    wit_table::new(PositionDebts{}, true, ctx)
  }
  
  public fun update_debt(
    debts: &mut WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
    amount: u64,
    borrowMark: Exp
  ) {
    if (wit_table::contains(debts, typeName)) {
      let debt = wit_table::borrow_mut(PositionDebts{}, debts, typeName);
      debt.amount = amount;
      debt.borrowMark = borrowMark;
    } else {
      let debt = Debt { amount, borrowMark };
      wit_table::add(PositionDebts{}, debts, typeName, debt);
    }
  }
  
  public fun debt(
    debts: &WitTable<PositionDebts, TypeName, Debt>,
    typeName: TypeName,
  ): (u64, Exp) {
    
    let debt = wit_table::borrow(debts, typeName);
    (debt.amount, debt.borrowMark)
  }
}
