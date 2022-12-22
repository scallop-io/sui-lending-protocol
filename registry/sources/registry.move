module registry::registry {
  
  use std::type_name::{TypeName};
  use sui::object::{Self, UID, ID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer;
  
  const ERegistryVerifyFailed: u64 = 0;
  
  struct Registry<phantom T: drop> has key {
    id: UID,
    registryTable: Table<TypeName, ID>
  }
  
  public fun create_registry<T: drop>(_: T, ctx: &mut TxContext) {
    let registry = Registry<T> {
      id: object::new(ctx),
      registryTable: table::new(ctx)
    };
    transfer::share_object(registry);
  }
  
  public fun register<T: drop, ItemType: key>(
    _: T,
    registry: &mut Registry<T>,
    typeName: TypeName,
    item: &ItemType,
  ) {
    table::add(&mut registry.registryTable, typeName, object::id(item))
  }
  
  public fun verify<T: drop, ItemType: key>(
    registry: &Registry<T>,
    typeName: TypeName,
    item: &ItemType,
  ) {
    let registerId = table::borrow(&registry.registryTable, typeName);
    assert!( object::id(item) == *registerId, ERegistryVerifyFailed);
  }
}
