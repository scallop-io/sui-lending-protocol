module protocol::value_calculator {
  
  use sui::math;
  use math::u64;
  use std::fixed_point32::{Self, FixedPoint32};
  use math::fixed_point32_empower;
  use std::debug;
  
  public fun usd_value(price: FixedPoint32, amount: u64, decimals: u8): FixedPoint32 {
    let price_raw_value = fixed_point32::get_raw_value(price);
    let usd_raw_value = u64::mul_div(price_raw_value, amount, math::pow(10, decimals));
    let usd_value = fixed_point32::create_from_raw_value(usd_raw_value);
    usd_value
  }

  #[test_only]
  public fun usd_value_old(price: FixedPoint32, amount: u64, decimals: u8): FixedPoint32 {
    let decimal_amount = fixed_point32::from_rational(amount, math::pow(10, decimals));
    fixed_point32_empower::mul(price, decimal_amount)
  }

  #[test]
  public fun test_usd_value() {
    let price = fixed_point32::from_rational(2627, 1000000);
    let amount = 20000350000 * math::pow(10, decimals);
    let decimals = 5;
    let val = usd_value(price, amount, decimals);
    debug::print(&val);
  }

  #[test]
  public fun test_usd_value_valid() {
    let price = fixed_point32::from_rational(2627, 1000000);
    let amount = 200003500 * math::pow(10, decimals);
    let decimals = 5;
    let val = usd_value(price, amount, decimals);
    let val_old = usd_value_old(price, amount, decimals);
    debug::print(&val);
    debug::print(&val_old);
    assert!(val == val_old, 0);
  }
}
