/**********
This module is used to store a value that could
only be accessed after a certain epoch, and may expire after a certain epoch.
And, the value could be consume only once.
**********/
module x::one_time_lock_value {
  
  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};

  const EValueExpired: u64 = 1;
  const EValuePending: u64 = 2;
  const ECannotDestoryNonExpiredValue: u64 = 3;
  
  struct OneTimeLockValue<T: store + copy + drop> has key, store {
    id: UID,
    value: T,
    lock_until_epoch: u64,
    valid_before_epoch: u64 // If expireEpoch is 0, then it will always be valid.
  }
  
  public fun lock_until_epoch<T: store + copy + drop>(self: &OneTimeLockValue<T>): u64 {self.lock_until_epoch}
  public fun valid_before_epoch<T: store + copy + drop>(self: &OneTimeLockValue<T>): u64 {self.valid_before_epoch}
  
  public fun new<T: store + copy + drop>(
    value: T,
    lock_epoches: u64, // how many epoches to lock
    valid_epoches: u64, // how long the value will be valid after lock
    ctx: &mut TxContext
  ): OneTimeLockValue<T> {
    let  cur_epoch = tx_context::epoch(ctx);
    let lock_until_epoch = cur_epoch + lock_epoches;
    let valid_before_epoch = if (valid_epoches > 0) { lock_until_epoch + valid_epoches } else 0;
    OneTimeLockValue {
      id: object::new(ctx),
      value,
      lock_until_epoch,
      valid_before_epoch
    }
  }
  
  // get the value from lock, value could only be accessed one time
  // - If 'lockUntilEpoch' is not met, then abort
  // - If 'validBeforeEpoch' is not 0, and has already passed, then abort
  // - After all conditions are met, return the value, and set 'consumed = true'
  public fun get_value<T: copy + store + drop>(self: OneTimeLockValue<T>, ctx: &mut TxContext): T {
    let OneTimeLockValue { id, value, valid_before_epoch, lock_until_epoch } = self;
    object::delete(id);

    let cur_epoch = tx_context::epoch(ctx);
    assert!(lock_until_epoch <= cur_epoch, EValuePending);
    if (valid_before_epoch > 0) {
      assert!( cur_epoch < valid_before_epoch, EValueExpired);
    };
    value
  }

  // Destroy the one time lock value if it expires
  // - If 'validBeforeEpoch' is 0, it will never expire, then cannot be destroyed
  // - If 'validBeforeEpoch' is not 0, and has already passed, then destroy
  public fun destroy<T: copy + store + drop>(self: OneTimeLockValue<T>, ctx: &mut TxContext) {
    let OneTimeLockValue { id, value: _, valid_before_epoch, lock_until_epoch: _ } = self;
    object::delete(id);

    let cur_epoch = tx_context::epoch(ctx);
    assert!(valid_before_epoch > 0, ECannotDestoryNonExpiredValue);
    assert!(cur_epoch >= valid_before_epoch, ECannotDestoryNonExpiredValue);
  }
}
