module playground::playground {
  
  public fun add(a: u64, b: u64): u64 {
    a + b
  }
  
  spec add {
    ensures result == a + b;
  }
}
