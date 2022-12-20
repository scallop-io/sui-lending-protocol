module mobius_admin::exponential {
  
  use std::error;
  
  // e18
  const EXP_SCALE: u128 = 1000000000000000000;
  const DOUBLE_SCALE: u128 = 1000000000000000000000000000000000000u128;
  
  //e36
  const HALF_EXP_SCALE: u128 = 1000000000000000000 / 2;
  const MANTISSA_ONE: u128 = 1000000000000000000;
  const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
  const U64_MAX: u128 = 18446744073709551615u128;
  
  
  const OVER_FLOW: u64 = 1001;
  const DIVIDE_BY_ZERO: u64 = 1002;
  
  struct Exp has copy, store, drop {
    mantissa: u128
  }
  
  struct Double has copy, store, drop {
    mantissa: u128
  }
  
  public fun exp_scale(): u128 {
    return EXP_SCALE
  }
  
  public fun exp(num: u128, denom: u128): Exp {
    //        if overflow move will abort
    let scaledNumerator = mul_u128((num as u128), EXP_SCALE);
    let rational = div_u128(scaledNumerator, (denom as u128));
    Exp {
      mantissa: rational
    }
  }
  
  public fun mantissa(a: Exp): u128 {
    a.mantissa
  }
  
  public fun add_exp(a: Exp, b: Exp): Exp {
    Exp {
      mantissa: add_u128(a.mantissa, b.mantissa)
    }
  }
  
  public fun sub_exp(a: Exp, b: Exp): Exp {
    Exp {
      mantissa: sub_u128(a.mantissa, b.mantissa)
    }
  }
  
  public fun mul_scalar_exp(a: Exp, scalar: u128): Exp {
    Exp {
      mantissa: mul_u128(a.mantissa, scalar)
    }
  }
  
  public fun mul_scalar_exp_truncate(a: Exp, scalar: u128): Exp {
    Exp {
      mantissa: truncate(mul_scalar_exp(a, scalar))
    }
  }
  
  public fun mul_scalar_exp_truncate_add(a: Exp, scalar: u128, addend: u128): u128 {
    let e = mul_scalar_exp(a, scalar);
    add_u128(truncate(e), addend)
  }
  
  
  public fun div_scalar_exp(a: Exp, scalar: u128): Exp {
    Exp {
      mantissa: div_u128(a.mantissa, scalar)
    }
  }
  
  public fun div_scalar_by_exp(scalar: u128, divisor: Exp): Exp {
    /*
     How it works:
     Exp = a / b;
     Scalar = s;
     `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
   */
    let numerator = mul_u128(EXP_SCALE, scalar);
    exp(numerator, divisor.mantissa)
  }
  
  public fun div_scalar_by_exp_truncate(scalar: u128, divisor: Exp): u128 {
    truncate(div_scalar_by_exp(scalar, divisor))
  }
  
  
  public fun mul_exp(a: Exp, b: Exp): Exp {
    let double_scaled_product = mul_u128(a.mantissa, b.mantissa);
    let double_scaled_product_with_half_scale = add_u128(HALF_EXP_SCALE, double_scaled_product);
    let product = div_u128(double_scaled_product_with_half_scale, EXP_SCALE);
    
    Exp {
      mantissa: product
    }
  }
  
  public fun mul_exp_u128(a: u128, b: u128): Exp {
    return mul_exp(Exp { mantissa: a }, Exp { mantissa: b })
  }
  
  public fun mul_exp_3(a: Exp, b: Exp, c: Exp): Exp {
    let m = mul_exp(a, b);
    mul_exp(m, c)
  }
  
  public fun div_exp(a: Exp, b: Exp): Exp {
    exp(a.mantissa, b.mantissa)
  }
  
  public fun truncate(exp: Exp): u128 {
    return exp.mantissa / EXP_SCALE
  }
  
  fun mul_scalar_truncate_(exp: Exp, scalar: u128): u128 {
    let v = mul_u128(exp.mantissa, scalar);
    truncate(Exp {
      mantissa: v
    })
  }
  
  fun mul_scalar_truncate_add_(exp: Exp, scalar: u128, addend: u128): u128 {
    let v = mul_u128(exp.mantissa, scalar);
    let truncate = truncate(Exp { mantissa: v });
    add_u128(truncate, addend)
  }
  
  public fun less_than_exp(left: Exp, right: Exp): bool {
    left.mantissa < right.mantissa
  }
  
  public fun less_than_or_equal_exp(left: Exp, right: Exp): bool {
    left.mantissa <= right.mantissa
  }
  
  public fun equal_exp(left: Exp, right: Exp): bool {
    left.mantissa == right.mantissa
  }
  
  public fun greater_than_exp(left: Exp, right: Exp): bool {
    left.mantissa > right.mantissa
  }
  
  public fun is_zero(exp: Exp): bool {
    exp.mantissa == 0
  }
  
  
  fun safe64(v: u128): u64 {
    if (v <= U64_MAX) {
      return (v as u64)
    };
    abort error::invalid_argument(OVER_FLOW)
  }
  
  fun add_u128(a: u128, b: u128): u128 {
    a + b
  }
  
  fun sub_u128(a: u128, b: u128): u128 {
    a - b
  }
  
  fun mul_u128(a: u128, b: u128): u128 {
    if (a == 0 || b == 0) {
      return 0
    };
    
    a * b
  }
  
  fun div_u128(a: u128, b: u128): u128 {
    if (b == 0) {
      abort error::invalid_argument(DIVIDE_BY_ZERO)
    };
    if (a == 0) {
      return 0
    };
    a / b
  }
  
  public fun fraction(a: u128, b: u128): Double {
    let v = div_u128(mul_u128(a, DOUBLE_SCALE), b);
    Double {
      mantissa: v
    }
  }
}

    