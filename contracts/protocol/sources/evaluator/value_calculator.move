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
  public fun usd_value_deprecated(price: FixedPoint32, amount: u64, decimals: u8): FixedPoint32 {
    let decimal_amount = fixed_point32::create_from_rational(amount, math::pow(10, decimals));
    fixed_point32_empower::mul(price, decimal_amount)
  }

  #[test]
  public fun test_usd_value() {
    let price = fixed_point32::create_from_rational(2627, 1_000_000); // $0.002627
    let decimals = 5;
    let amount = 20_000_350_000 * math::pow(10, decimals);
    let val = usd_value(price, amount, decimals);
    debug::print(&val);
  }

  #[test]
  public fun test_usd_value_result_should_equal() {
    let price = fixed_point32::create_from_rational(2627, 1_000_000); // $0.002627
    let decimals = 5;
    let amount = 200_003_500 * math::pow(10, decimals);
    let val = usd_value(price, amount, decimals);
    let val_old = usd_value_deprecated(price, amount, decimals);
    debug::print(&val);
    debug::print(&val_old);
    assert!(val == val_old, 0);
  }

  #[test]
  fun test_usd_value_with_big_amount() {
    let price = fixed_point32::create_from_rational(257, math::pow(10, 9)); // 0.000000257
    let amount: u64 = 4_300_000_000_000 * math::pow(10, 5); // 4.3T with 5 decimals
    let usd_value = usd_value(price, amount, 5);
    std::debug::print(&usd_value);

    let price = fixed_point32::create_from_rational(10425073, math::pow(10, 2));
    let amount: u64 = 10_000 * math::pow(10, 2);
    let usd_value = usd_value(price, amount, 2);
    std::debug::print(&usd_value);
  }

  #[test, expected_failure]
  fun test_usd_value_with_big_amount_failure() {
    let price = fixed_point32::create_from_rational(257, math::pow(10, 9)); // 0.000000257
    let amount: u64 = 4_300_000_000_000 * math::pow(10, 5); // 4.3T with 5 decimals
    let usd_value = usd_value(price, amount, 5);
    std::debug::print(&usd_value);

    // should failure here
    let usd_value = usd_value_deprecated(price, amount, 5);
    std::debug::print(&usd_value);
  }
}
