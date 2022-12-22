module registry::typed_registry {
  
  use std::type_name::{TypeName};
  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::typed_id::TypedID;
  use sui::typed_id;
  
  const ERegistryVerifyFailed: u64 = 0;
  
  struct Registry<phantom T: drop, phantom ItemType: key> has key {
    id: UID,
    registryTable: Table<TypeName, TypedID<ItemType>>
  }
  
  public fun create_registry<T: drop, ItemType: key>(_: T, ctx: &mut TxContext) {
    let registry = Registry<T, ItemType> {
      id: object::new(ctx),
      registryTable: table::new(ctx)
    };
    transfer::share_object(registry);
  }
  
  public fun register<T: drop, ItemType: key>(
    _: T,
    registry: &mut Registry<T, ItemType>,
    typeName: TypeName,
    item: &ItemType,
  ) {
    let typedId = typed_id::new(item);
    table::add(&mut registry.registryTable, typeName, typedId)
  }
  
  public fun verify<T: drop, ItemType: key>(
    registry: &Registry<T, ItemType>,
    typeName: TypeName,
    item: &ItemType,
  ) {
    let registerId = table::borrow(&registry.registryTable, typeName);
    assert!( typed_id::equals_object(registerId, item), ERegistryVerifyFailed)
  }
}
