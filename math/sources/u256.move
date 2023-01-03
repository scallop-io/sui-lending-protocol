module math::u256 {
  
  const DIVIDE_BY_ZERO: u64 = 1002;
  const U256_MAX: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  
  public fun mul_div(a: u256, b: u256, c: u256): u256 {
    let (a , b) = if (a >= b) {
      (a, b)
    } else {
      (b, a)
    };
    assert!(c > 0, DIVIDE_BY_ZERO);
    // It will over flow when a * b > U256_MAX
    if (U256_MAX / a < b) {
      a / c * b
    } else {
      a * b / c
    }
  }
}
