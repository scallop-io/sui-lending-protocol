module math::u128 {
  
  const DIVIDE_BY_ZERO: u64 = 1002;
  const U128_MAX: u128 = 340282366920938463463374607431768211455;
  
  public fun mul_div(a: u128, b: u128, c: u128): u128 {
    let (a , b) = if (a >= b) {
      (a, b)
    } else {
      (b, a)
    };
    assert!(c > 0, DIVIDE_BY_ZERO);
    // It will over flow when a * b
    if (U128_MAX / a < b) {
      a / c * b
    } else {
      a * b / c
    }
  }
}
