// d stands for fixed point decimals
// 1. The truncated result will always be u64, otherwise abort
// 2. Only temporal result will be bigger than u64
module math::fr {
  use math::u256;
  
  // e18
  const SCALE: u256 = 1000000000000000000;
  
  const U64_MAX: u256 = 18446744073709551615;
  const OVER_FLOW: u64 = 1001;
  
  struct Fr has copy, store, drop {
    mantissa: u256
  }
  
  public fun fr(enu: u64, deno: u64): Fr {
    let enu = (enu as u256);
    let deno = (deno as u256);
    Fr {
      mantissa: u256::mul_div(enu, SCALE, deno)
    }
  }
  
  public fun int(int: u64): Fr {
    Fr {
      mantissa: (int as u256) * SCALE
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
      mantissa: u256::mul_div(f1.mantissa, f2.mantissa, SCALE)
    }
  }
  
  public fun div(f1: Fr, f2: Fr): Fr {
    Fr {
      mantissa: u256::mul_div(f1.mantissa, SCALE, f2.mantissa)
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
  
  public fun mul_i(f1: Fr, i2: u64): Fr {
    Fr {
      mantissa: f1.mantissa * (i2 as u256)
    }
  }
  
  public fun mul_iT(f1: Fr, i2: u64): u64 {
    trunc(mul_i(f1, i2))
  }
}
