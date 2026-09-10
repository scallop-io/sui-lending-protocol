module protocol::value_calculator {
  
  use sui::math;
use math::UQ32_32_empower;
  use std::uq32_32::{Self, UQ32_32};
  // use math::uq32_32_empower;
  use std::debug;
  use std::u64;
  
  public fun usd_value(price: UQ32_32, amount: u64, decimals: u8): UQ32_32 {
    let price_raw_value = uq32_32::to_raw(price);
    let usd_raw_value = u64::mul_div(price_raw_value, amount, std::u64::pow(10, decimals));
    let usd_value = uq32_32::from_raw(usd_raw_value);
    usd_value
  }

  #[test_only]
  public fun usd_value_deprecated(price: UQ32_32, amount: u64, decimals: u8): UQ32_32 {
    let decimal_amount = uq32_32::from_quotient(amount, std::u64::pow(10, decimals));
    UQ32_32_empower::mul(price, decimal_amount)
  }

  #[test]
  public fun test_usd_value() {
    let price = uq32_32::from_quotient(2627, 1_000_000); // $0.002627
    let decimals = 5;
    let amount = 20_000_350_000 * std::u64::pow(10, decimals);
    let val = usd_value(price, amount, decimals);
    debug::print(&val);
  }

  #[test]
  public fun test_usd_value_result_should_equal() {
    let price = uq32_32::from_quotient(2627, 1_000_000); // $0.002627
    let decimals = 5;
    let amount = 200_003_500 * std::u64::pow(10, decimals);
    let val = usd_value(price, amount, decimals);
    let val_old = usd_value_deprecated(price, amount, decimals);
    debug::print(&val);
    debug::print(&val_old);
    assert!(val == val_old, 0);
  }

  #[test]
  fun test_usd_value_with_big_amount() {
    let price = uq32_32::from_quotient(257, std::u64::pow(10, 9)); // 0.000000257
    let amount: u64 = 4_300_000_000_000 * std::u64::pow(10, 5); // 4.3T with 5 decimals
    let usd_value = usd_value(price, amount, 5);
    std::debug::print(&usd_value);

    let price = uq32_32::from_quotient(10425073, std::u64::pow(10, 2));
    let amount: u64 = 10_000 * std::u64::pow(10, 2);
    let usd_value = usd_value(price, amount, 2);
    std::debug::print(&usd_value);
  }

  #[test, expected_failure]
  fun test_usd_value_with_big_amount_failure() {
    let price = uq32_32::from_quotient(257, std::u64::pow(10, 9)); // 0.000000257
    let amount: u64 = 4_300_000_000_000 * std::u64::pow(10, 5); // 4.3T with 5 decimals
    let usd_value = usd_value(price, amount, 5);
    std::debug::print(&usd_value);

    // should failure here
    let usd_value = usd_value_deprecated(price, amount, 5);
    std::debug::print(&usd_value);
  }
}
