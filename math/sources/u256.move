module math::u256 {

  const DIVIDE_BY_ZERO: u64 = 1002;
  const CALCULATION_OVERFLOW: u64 = 1003;
  const U256_MAX: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  
  /// Return the value of a * b / c
  public fun mul_div(a: u256, b: u256, c: u256): u256 {
    let (a , b) = if (a >= b) {
      (a, b)
    } else {
      (b, a)
    };

    assert!(c > 0, DIVIDE_BY_ZERO);

    if (!is_safe_mul(a, b)) {
      // formula: ((a / c) * b) + (((a % c) * b) / c)
      checked_mul((a / c), b) + (checked_mul((a % c), b) / c)
    } else {
      a * b / c
    }
  }

  /// Return value of x * y with checking the overflow
  public fun checked_mul(x: u256, y: u256): u256 {
    assert!(is_safe_mul(x, y), CALCULATION_OVERFLOW);
    x * y
  }

  /// Check whether x * y doesn't lead to overflow
  public fun is_safe_mul(x: u256, y: u256): bool {
    (U256_MAX / x >= y)
  }
}
