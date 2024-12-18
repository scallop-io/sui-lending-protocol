module protocol::value_calculator {
  
  use sui::math;
  use math::u64;
  use std::fixed_point32::{Self, FixedPoint32};
  use math::fixed_point32_empower;
  
  public fun usd_value(price: FixedPoint32, amount: u64, decimals: u8): FixedPoint32 {
    let price_raw_value = fixed_point32::get_raw_value(price);
    let usd_raw_value = u64::mul_div(price_raw_value, amount, math::pow(10, decimals));
    let usd_value = fixed_point32::create_from_raw_value(usd_raw_value);
    usd_value
  }
}
