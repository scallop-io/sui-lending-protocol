module math::mix {
  
  use math::fr::{Self, Fr};
  
  /// ifr stands for "int and fraction"
  /// multiple u64 and fraction
  public fun mul_ifr(i: u64, f: Fr): Fr {
    fr::mul(fr::int(i), f)
  }
  
  /// ifr stands for "int and fraction"
  /// T stands for truncate
  /// multiple u64 and fraction then truncate
  public fun mul_ifrT(i: u64, f: Fr): u64 {
    fr::trunc(mul_ifr(i, f))
  }
  
  /// divide u64 by fraction
  public fun div_ifr(i: u64, f: Fr): Fr {
    fr::div(fr::int(i), f)
  }
  
  /// divide u64 by fraction, then truncate
  public fun div_ifrT(i: u64, f: Fr): u64 {
    fr::trunc(div_ifr(i, f))
  }
  
  /// add u64 and fraction
  public fun add_ifr(i: u64, f: Fr): Fr {
    fr::add(fr::int(i), f)
  }
  
  /// sub u64 and fraction
  public fun sub_ifr(i: u64, f: Fr): Fr {
    fr::sub(fr::int(i), f)
  }
}

