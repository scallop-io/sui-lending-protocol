/// TODO: find a flexible way to get decimals
module mobius_protocol::coin_decimals_registry {
  
  use std::type_name::{Self, TypeName};
  use sui::table::{Self, Table};
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  // use sui::coin::{Self, CoinMetadata};
  
  struct CoinDecimalsRegistry has key, store {
    id: UID,
    table: Table<TypeName, u8>
  }
  
  public fun new(ctx: &mut TxContext): CoinDecimalsRegistry {
    CoinDecimalsRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    }
  }
  
  /// TODO: use this registry add when coinMeta is readable
  // Since coinMeta is 1:1 for a coin,
  // CoinMeta is the single source of truth for the coin
  // Anyone can add the registry
  // public entry fun register_decimals<T>(
  //   registry: &mut CoinDecimalsRegistry,
  //   coinMeta: &CoinMetadata<T>
  // ) {
  //   let typeName = type_name::get<T>();
  //   // Returns the decimals of this coin
  //   // Adding this read method, won't cause any issues for coin framework
  //   let decimals = coin::decimals(coinMeta);
  //   table::add(&mut registry.table, typeName, decimals);
  // }
  
  public entry fun register_decimals<T>(
    registry: &mut CoinDecimalsRegistry,
    decimals: u8
  ) {
    let typeName = type_name::get<T>();
    table::add(&mut registry.table, typeName, decimals);
  }
  
  public fun get_decimals<T>(
    registry: &CoinDecimalsRegistry,
  ): u8 {
    let typeName = type_name::get<T>();
    *table::borrow(&registry.table, typeName)
  }
}
