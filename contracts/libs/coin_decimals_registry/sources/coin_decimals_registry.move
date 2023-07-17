module coin_decimals_registry::coin_decimals_registry {

  use std::ascii::String;
  use std::type_name::{Self, TypeName};
  use sui::table::{Self, Table};
  use sui::object::{Self, UID};
  use sui::coin::{Self, CoinMetadata};
  use sui::sui::SUI;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::package;
  use sui::event::emit;

  const EDecimalsNotFound: u64 = 999;

  struct COIN_DECIMALS_REGISTRY has drop {}

  struct CoinDecimalsRegistry has key, store {
    id: UID,
    table: Table<TypeName, u8>
  }

  struct CoinDecimalsRegistered has copy, drop {
    registry: address,
    coin_type: String,
    decimals: u8,
  }
  
  fun init(otw: COIN_DECIMALS_REGISTRY, ctx: &mut TxContext){
    package::claim_and_keep(otw, ctx);
    let registry = CoinDecimalsRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    // currently SUI metadata is hardcoded
    // reference: https://discord.com/channels/916379725201563759/955861929346355290/1068845540068048959
    table::add(&mut registry.table, type_name::get<SUI>(), 9);
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

    if (table::contains(&registry.table, type_name)) {
      return
    };
    table::add(&mut registry.table, type_name, decimals);
    emit(CoinDecimalsRegistered {
      registry: object::id_to_address(&object::id(registry)),
      coin_type: type_name::into_string(type_name),
      decimals,
    })
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
    assert!(table::contains(&registry.table, typeName), EDecimalsNotFound);
    *table::borrow(&registry.table, typeName)
  }
  
  public fun registry_table(
    registry: &CoinDecimalsRegistry,
  ): &Table<TypeName, u8> {
    &registry.table
  }
}
