module time::timestamp {
  
  use sui::object::UID;
  
  const ETravelback: u64 = 0;
  
  struct TimeStamp has key {
    id: UID,
    tiemstamp: u64
  }
  
  public fun timestamp(self: &TimeStamp): u64 {
    self.tiemstamp
  }
  
  public entry fun update(
    self: &mut TimeStamp,
    timestamp: u64,
  ) {
    assert!(timestamp > self.tiemstamp, ETravelback);
    self.tiemstamp = timestamp;
  }
}
