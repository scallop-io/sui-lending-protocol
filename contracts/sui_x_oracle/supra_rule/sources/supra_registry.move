module supra_rule::supra_registry {

  use std::type_name::{Self, TypeName};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;


  const ERR_ILLEGAL_SUPRA_PAIR: u64 = 0x11306;
  const ERR_ILLEGAL_REGISTRY_CAP: u64 = 0x11307;

  struct SupraRegistry has key {
    id: UID,
    table: Table<TypeName, u32>
  }
  struct SupraRegistryCap has key, store {
    id: UID,
    for: ID,
  }

  fun init(ctx: &mut TxContext) {
    let supra_registry = SupraRegistry {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    let supra_registry_cap = SupraRegistryCap {
      id: object::new(ctx),
      for: object::id(&supra_registry)
    };
    transfer::share_object(supra_registry);
    transfer::transfer(supra_registry_cap, tx_context::sender(ctx));
  }

  public entry fun register_supra_pair_id<CoinType>(
    supra_registry: &mut SupraRegistry,
    supra_registry_cap: &SupraRegistryCap,
    pair_id: u32,
  ) {
    assert!(object::id(supra_registry) == supra_registry_cap.for, ERR_ILLEGAL_REGISTRY_CAP);
    let coin_type = type_name::get<CoinType>();
    if (table::contains(&supra_registry.table, coin_type)) {
      table::remove<TypeName, u32>(&mut supra_registry.table, coin_type);
    };
    table::add(&mut supra_registry.table, coin_type, pair_id);
  }

  public entry fun get_supra_pair_id<CoinType>(
    supra_registry: &SupraRegistry,
  ): u32 {
    let coin_type = type_name::get<CoinType>();
    let pair_id = table::borrow<TypeName, u32>(&supra_registry.table, coin_type);
    *pair_id
  }

  public fun assert_supra_pair_id<CoinType>(
    supra_registry: &SupraRegistry,
    pair_id: u32,
  ) {
    let coin_type = type_name::get<CoinType>();
    let registerred_pair_id = table::borrow(&supra_registry.table, coin_type);
    assert!(pair_id == *registerred_pair_id, ERR_ILLEGAL_SUPRA_PAIR);
  }
}
