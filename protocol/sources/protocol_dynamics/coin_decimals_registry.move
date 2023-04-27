module protocol::coin_decimals_registry {
  
  use std::type_name::{Self, TypeName};
  use sui::table::{Self, Table};
  use sui::object::{Self, UID};
  use sui::coin::{Self, CoinMetadata};
  use sui::tx_context::TxContext;
  use sui::transfer;
  
  
  struct CoinDecimalsRegistry has key, store {
    id: UID,
    table: Table<TypeName, u8>
  }
  
  fun init(ctx: &mut TxContext){
    let registry = CoinDecimalsRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    transfer::public_share_object(registry);
  }
  
  #[test_only]
  public fun init_t(ctx: &mut TxContext){
    let registry = CoinDecimalsRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    transfer::public_share_object(registry);
  }
  
  // Since coinMeta is 1:1 for a coin,
  // CoinMeta is the single source of truth for the coin
  // Anyone can add the registry
  public entry fun register_decimals<T>(
    registry: &mut CoinDecimalsRegistry,
    coin_meta: &CoinMetadata<T>
  ) {
    let type_name = type_name::get<T>();
    let decimals = coin::get_decimals(coin_meta);
    table::add(&mut registry.table, type_name, decimals);
  }
  
  #[test_only]
  public fun register_decimals_t<T>(
    registry: &mut CoinDecimalsRegistry,
    decimals: u8,
  ) {
    let type_name = type_name::get<T>();
    table::add(&mut registry.table, type_name, decimals);
  }
  
  public fun decimals(
    registry: &CoinDecimalsRegistry,
    typeName: TypeName,
  ): u8 {
    *table::borrow(&registry.table, typeName)
  }
  
  public fun registry_table(
    registry: &CoinDecimalsRegistry,
  ): &Table<TypeName, u8> {
    &registry.table
  }
}
