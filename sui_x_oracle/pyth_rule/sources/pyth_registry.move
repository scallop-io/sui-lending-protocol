module pyth_rule::pyth_registry {

  use std::type_name::{Self, TypeName};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use pyth::price_info::PriceInfoObject;

  const ERR_ILLEGAL_PYTH_PRICE_OBJECT: u64 = 0;
  const ERR_ILLEGAL_REGISTRY_CAP: u64 = 1;

  struct PythRegistry has key {
    id: UID,
    table: Table<TypeName, ID>
  }
  struct PythRegistryCap has key, store {
    id: UID,
    for: ID,
  }

  fun init(ctx: &mut TxContext) {
    let pyth_registry = PythRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    let pyth_registry_cap = PythRegistryCap {
      id: object::new(ctx),
      for: object::id(&pyth_registry)
    };
    transfer::share_object(pyth_registry);
    transfer::transfer(pyth_registry_cap, tx_context::sender(ctx));
  }

  public entry fun register_pyth_price_info_object<CoinType>(
    pyth_registry: &mut PythRegistry,
    pyth_registry_cap: &PythRegistryCap,
    pyth_info_object: &PriceInfoObject,
  ) {
    assert!(object::id(pyth_registry) == pyth_registry_cap.for, ERR_ILLEGAL_REGISTRY_CAP);
    let coin_type = type_name::get<CoinType>();
    if (table::contains(&pyth_registry.table, coin_type)) {
      table::remove<TypeName, ID>(&mut pyth_registry.table, coin_type);
    };
    table::add(&mut pyth_registry.table, coin_type, object::id(pyth_info_object));
  }

  public fun assert_pyth_price_info_object<CoinType>(
    pyth_registry: &PythRegistry,
    price_info_object: &PriceInfoObject,
  ) {
    let coin_type = type_name::get<CoinType>();
    let coin_price_info_object_id = table::borrow(&pyth_registry.table, coin_type);
    assert!(object::id(price_info_object) == *coin_price_info_object_id, ERR_ILLEGAL_PYTH_PRICE_OBJECT);
  }
}
