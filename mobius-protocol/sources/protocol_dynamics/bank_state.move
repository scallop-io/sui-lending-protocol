module mobius_protocol::bank_state {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  
  struct BankState has store {
    cash: u64,
    debt: u64,
    reserve: u64,
  }
  
  struct BankStates has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<BankStates, TypeName, BankState> {
    wit_table::new<BankStates, TypeName, BankState>(
      BankStates{},
      false,
      ctx
    )
  }
  
  public fun update_bank_state(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName,
    debt: u64,
    cash: u64,
    reserve: u64,
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    stat.debt = debt;
    stat.cash = cash;
    stat.reserve = reserve;
  }
  
  public fun increase_debt(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName,
    newDebt: u64,
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    stat.debt = stat.debt + newDebt;
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun get_bank_state(
    self: &WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName
  ): (u64, u64, u64) {
    let stat = wit_table::borrow(self, typeName);
    (stat.debt, stat.cash, stat.reserve)
  }
}
