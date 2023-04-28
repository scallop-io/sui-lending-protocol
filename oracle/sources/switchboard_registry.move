module oracle::switchboard_registry {

  use std::type_name::{Self, TypeName};
  use sui::object::{Self, ID, UID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use switchboard::aggregator::Aggregator;
  use x::ac_table::{Self, AcTable, AcTableCap};

  const SWITCHBOARD_AGGREGATOR_NOT_REGISTERED: u64 = 1;

  struct SwitchboardRegistryWit has drop {}

  struct SwitchboardRegistry has key {
    id: UID,
    table: AcTable<SwitchboardRegistryWit, TypeName, ID>
  }

  struct SwitchboardRegistryCap has key, store {
    id: UID,
    cap: AcTableCap<SwitchboardRegistryWit>
  }

  fun init(ctx: &mut TxContext) {
    let (registry_ac_table, ac_table_cap) = ac_table::new(SwitchboardRegistryWit{}, true, ctx );
    let registry = SwitchboardRegistry {
      id: object::new(ctx),
      table: registry_ac_table,
    };
    let registry_cap = SwitchboardRegistryCap {
      id: object::new(ctx),
      cap: ac_table_cap,
    };
    transfer::share_object(registry);
    transfer::transfer(registry_cap, tx_context::sender(ctx));
  }

  public entry fun register_aggregator<CoinType>(
    registry_cap: &SwitchboardRegistryCap,
    registry: &mut SwitchboardRegistry,
    aggregator: &Aggregator,
  ) {
    let coin_type = type_name::get<CoinType>();
    let aggregator_id = object::id(aggregator);
    ac_table::add(
      &mut registry.table,
      &registry_cap.cap,
      coin_type,
      aggregator_id,
    );
  }

  public fun get_aggregator_id(
    registry: &SwitchboardRegistry,
    coin_type: TypeName,
  ): ID {
    *ac_table::borrow(&registry.table, coin_type)
  }

  public fun assert_aggregator(
    registry: &SwitchboardRegistry,
    coin_type: TypeName,
    aggregator: &Aggregator,
  ) {
    let aggregator_id = object::id(aggregator);

    let registry_aggregator_id = ac_table::borrow(
      &registry.table,
      coin_type,
    );
    assert!(aggregator_id == *registry_aggregator_id, SWITCHBOARD_AGGREGATOR_NOT_REGISTERED);
  }
}
