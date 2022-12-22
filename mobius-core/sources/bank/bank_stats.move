module mobius_core::bank_stats {
  
  use std::type_name::{Self, TypeName};
  use sui::tx_context::TxContext;
  use sui::transfer;
  
  use x::wit_table::{Self, WitTable};
  use sui::object::UID;
  use sui::object;
  
  friend  mobius_core::bank;
  
  struct Stat has store {
    cash: u64,
    debt: u64,
    reserve: u64,
  }
  
  struct BankStatsTable has drop {}
  
  struct BankStats has key {
    id: UID,
    table: WitTable<BankStatsTable, TypeName, Stat>
  }
  
  fun init(ctx: &mut TxContext) {
    let bankStatsTable = wit_table::new<BankStatsTable, TypeName, Stat>(BankStatsTable{}, ctx);
    let bankStats = BankStats {
      id: object::new(ctx),
      table: bankStatsTable,
    };
    transfer::share_object(bankStats)
  }
  
  public(friend) fun update<T>(
    self: &mut BankStats,
    debt: u64,
    cash: u64,
    reserve: u64,
  ) {
    let typeName = type_name::get<T>();
    let stat = wit_table::borrow_mut(BankStatsTable{}, &mut self.table, typeName);
    stat.debt = debt;
    stat.cash = cash;
    stat.reserve = reserve;
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun get(
    self: &BankStats,
    typeName: TypeName
  ): (u64, u64, u64) {
    let stat = wit_table::borrow(&self.table, typeName);
    (stat.debt, stat.cash, stat.reserve)
  }
}
