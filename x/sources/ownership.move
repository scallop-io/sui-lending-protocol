module x::ownership {
  
  use sui::object::{Self, UID, ID};
  use sui::tx_context::TxContext;
  
  const ENotOwner: u64 = 0;
  
  struct Ownership<phantom T: drop> has key, store {
    id: UID,
    of: ID,
  }
  
  public fun create_ownership<T: drop>(
    _: T,
    itemId: ID,
    ctx: &mut TxContext
  ): Ownership<T> {
    Ownership {
      id: object::new(ctx),
      of: itemId
    }
  }
  
  public fun is_owner<T: drop, Item: key>(
    ownership: &Ownership<T>,
    item: &Item,
  ): bool {
    ownership.of == object::id(item)
  }
  
  public fun assert_owner<T: drop, Item: key>(
    ownership: &Ownership<T>,
    item: &Item,
  ) {
    assert!(is_owner(ownership, item), ENotOwner);
  }
}
