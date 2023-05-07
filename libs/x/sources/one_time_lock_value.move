/**********
This module is used to store a value that could
only be accessed after a certain epoch, and may expire after a certain epoch.
And, the value could be consume only once.
**********/
module x::one_time_lock_value {
  
  use sui::object::UID;
  use sui::tx_context::TxContext;
  use sui::object;
  use sui::tx_context;
  
  const EAlreadyConsumed: u64 = 0;
  const EValueExpired: u64 = 1;
  const EValuePending: u64 = 2;
  
  struct OneTimeLockValue<T: store + copy> has key, store {
    id: UID,
    value: T,
    consumed: bool,
    lock_until_epoch: u64,
    valid_before_epoch: u64 // If expireEpoch is 0, then it will always be valid.
  }
  
  public fun consumed<T: store + copy>(self: &OneTimeLockValue<T>): bool {self.consumed}
  public fun lock_until_epoch<T: store + copy>(self: &OneTimeLockValue<T>): u64 {self.lock_until_epoch}
  public fun valid_before_epoch<T: store + copy>(self: &OneTimeLockValue<T>): u64 {self.valid_before_epoch}
  
  public fun new<T: store + copy>(
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
      consumed: false,
      lock_until_epoch,
      valid_before_epoch
    }
  }
  
  // get the value from lock, value could only be accessed one time
  // - If 'lockUntilEpoch' is not met, then abort
  // - If 'validBeforeEpoch' is not 0, and has already passed, then abort
  // - If 'consumed' is true, then abort
  // - After all conditions are met, return the value, and set 'consumed = true'
  public fun get_value<T: copy + store>(self: &mut OneTimeLockValue<T>, ctx: &mut TxContext): T {
    let cur_epoch = tx_context::epoch(ctx);
    assert!(self.lock_until_epoch <= cur_epoch, EValuePending);
    if (self.valid_before_epoch > 0) {
      assert!(self.valid_before_epoch > cur_epoch, EValueExpired)
    };
    assert!(self.consumed == false, EAlreadyConsumed);
    self.consumed = true;
    self.value
  }
}
