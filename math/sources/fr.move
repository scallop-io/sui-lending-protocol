// d stands for fixed point decimals
// 1. The truncated result will always be u64, otherwise abort
// 2. Only temporal result will be bigger than u64
module math::fr {
  use math::u128;
  
  // e18
  const SCALE: u128 = 1000000000000000000;
  
  const U64_MAX: u128 = 18446744073709551615u128;
  const OVER_FLOW: u64 = 1001;
  
  struct Fr has copy, store, drop {
    mantissa: u128
  }
  
  public fun fr(enu: u64, deno: u64): Fr {
    let enu = (enu as u128);
    let deno = (deno as u128);
    Fr {
      mantissa: u128::mul_div(enu, SCALE, deno)
    }
  }
  
  public fun int(int: u64): Fr {
    Fr {
      mantissa: (int as u128) * SCALE
    }
  }
  
  public fun add(f1: Fr, f2: Fr): Fr {
    Fr {
      mantissa: f1.mantissa + f2.mantissa
    }
  }
  
  public fun sub(f1: Fr, f2: Fr): Fr {
    Fr {
      mantissa: f1.mantissa - f2.mantissa
    }
  }
  
  public fun mul(f1: Fr, f2: Fr): Fr {
    Fr {
      mantissa: u128::mul_div(f1.mantissa, f2.mantissa, SCALE)
    }
  }
  
  public fun div(f1: Fr, f2: Fr): Fr {
    Fr {
      mantissa: u128::mul_div(f1.mantissa, SCALE, f2.mantissa)
    }
  }
  
  public fun zero(): Fr {
    Fr { mantissa: 0 }
  }
  
  public fun gt(f1: Fr, f2: Fr): bool {
    f1.mantissa > f2.mantissa
  }
  
  public fun trunc(d: Fr): u64 {
    let truncated = d.mantissa / SCALE;
    assert!(truncated < U64_MAX, OVER_FLOW);
    (truncated as u64)
  }
  
  public fun mulT(f1: Fr, f2: Fr): u64 {
    trunc(mul(f1, f2))
  }
  
  public fun divT(f1: Fr, f2: Fr): u64 {
    trunc(div(f1, f2))
  }
}
