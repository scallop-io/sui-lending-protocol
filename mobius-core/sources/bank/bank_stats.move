module mobius_core::bank_stats {
  
  use sui::object::UID;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::object;
  use sui::table::Table;
  use std::type_name::{TypeName};
  use sui::table;
  use std::type_name;
  
  friend  mobius_core::bank;
  
  
  struct Stat has store {
    cash: u64,
    debt: u64,
    reserve: u64,
  }
  
  struct BankStats has key {
    id: UID,
    stats: Table<TypeName, Stat>
  }
  
  fun init(ctx: &mut TxContext) {
    transfer::share_object(
      BankStats {
        id: object::new(ctx),
        stats: table::new(ctx)
      }
    )
  }
  
  public(friend) fun update<T>(
    self: &mut BankStats,
    debt: u64,
    cash: u64,
    reserve: u64,
  ) {
    let typeName = type_name::get<T>();
    let stat = table::borrow_mut(&mut self.stats, typeName);
    stat.debt = debt;
    stat.cash = cash;
    stat.reserve = reserve;
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun get(
    self: &BankStats,
    typeName: TypeName
  ): (u64, u64, u64) {
    let stat = table::borrow(&self.stats, typeName);
    (stat.debt, stat.cash, stat.reserve)
  }
}
