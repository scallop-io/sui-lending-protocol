module lock::lock {
  
  use sui::object::{Self, UID, ID};
  use sui::tx_context::TxContext;
  
  const EKeyNotMatch: u64 = 0;
  
  struct Key<phantom KeyType: drop> has key, store {
    id: UID,
    to: ID,
  }
  
  struct Lock<T: store> has key {
    id: UID,
    obj: T
  }
  
  // Lock the object, and return the key, and lock
  public fun new<KeyType: drop, LockObjectType: store>(
    _: KeyType,
    obj: LockObjectType,
    ctx: &mut TxContext,
  ) : (Key<KeyType>, Lock<LockObjectType>) {
    let lock = Lock {
      id: object::new(ctx),
      obj,
    };
    let key = Key<KeyType> {
      id: object::new(ctx),
      to: object::id(&lock),
    };
    (key, lock)
  }
  
  public fun unlock<KeyType: drop, LockObjectType: store>(
    key: Key<KeyType>,
    lock: Lock<LockObjectType>,
  ) : LockObjectType {
    assert!(key.to == object::id(&lock), EKeyNotMatch);
    let Lock { id, obj } = lock;
    object::delete(id);
    let Key { id, to: _ } = key;
    object::delete(id);
    obj
  }
}
