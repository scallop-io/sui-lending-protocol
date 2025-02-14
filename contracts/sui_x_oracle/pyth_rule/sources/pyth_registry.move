module pyth_rule::pyth_registry {

  use std::type_name::{Self, TypeName};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use pyth::price_info::PriceInfoObject;

  const ERR_ILLEGAL_PYTH_PRICE_OBJECT: u64 = 0x11205;
  const ERR_ILLEGAL_REGISTRY_CAP: u64 = 0x11206;
  const ERR_INVALID_CONF_TOLERANCE: u64 = 0x11207;

  const CONF_TOLERANCE_DENOMINATOR: u64 = 10_000;

  struct PythFeedData has store, drop {
    feed: ID,
    conf_tolerance: u64, // confidence
  }
  struct PythRegistry has key {
    id: UID,
    table: Table<TypeName, PythFeedData>,
  }
  struct PythRegistryCap has key, store {
    id: UID,
    for: ID,
  }

  public fun conf_tolerance_denominator(): u64 {
    CONF_TOLERANCE_DENOMINATOR
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

  public fun pyth_feed_data(
    pyth_registry: &PythRegistry,
    coin_type: TypeName,
  ): &PythFeedData {
    table::borrow(&pyth_registry.table, coin_type)
  }

  public fun price_feed_id(pyth_feed_data: &PythFeedData): ID {
    pyth_feed_data.feed
  }

  public fun price_conf_tolerance(pyth_feed_data: &PythFeedData): u64 {
    pyth_feed_data.conf_tolerance
  }

  public entry fun register_pyth_feed<CoinType>(
    pyth_registry: &mut PythRegistry,
    pyth_registry_cap: &PythRegistryCap,
    pyth_info_object: &PriceInfoObject,
    pyth_feed_confidence_tolerance: u64, // per 10,000. so 1 = 0.01%
  ) {
    assert!(pyth_feed_confidence_tolerance <= conf_tolerance_denominator(), ERR_INVALID_CONF_TOLERANCE);
    assert!(object::id(pyth_registry) == pyth_registry_cap.for, ERR_ILLEGAL_REGISTRY_CAP);
    let coin_type = type_name::get<CoinType>();
    if (table::contains(&pyth_registry.table, coin_type)) {
      table::remove<TypeName, PythFeedData>(&mut pyth_registry.table, coin_type);
    };
    table::add(&mut pyth_registry.table, coin_type, 
    PythFeedData {
      feed: object::id(pyth_info_object),
      conf_tolerance: pyth_feed_confidence_tolerance,
    });
  }

  public fun assert_pyth_price_info_object<CoinType>(
    pyth_registry: &PythRegistry,
    price_info_object: &PriceInfoObject,
  ) {
    let coin_type = type_name::get<CoinType>();
    let pyth_feed_data = table::borrow(&pyth_registry.table, coin_type);
    assert!(object::id(price_info_object) == pyth_feed_data.feed, ERR_ILLEGAL_PYTH_PRICE_OBJECT);
  }
}
