/***
This is the helper module for std::fixed_point32
*/
module math::fixed_point32_empower {
  use std::fixed_point32::{Self, FixedPoint32};
  
  // Add 2 FixedPoint32 numers
  public fun add(a: FixedPoint32, b: FixedPoint32): FixedPoint32 {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    fixed_point32::create_from_raw_value(a_raw + b_raw)
  }
  
  // Substract 2 FixedPoint32 numers
  public fun sub(a: FixedPoint32, b: FixedPoint32): FixedPoint32 {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    fixed_point32::create_from_raw_value(a_raw - b_raw)
  }
  
  // Divide 2 FixedPoint32 numers
  public fun div(a: FixedPoint32, b: FixedPoint32): FixedPoint32 {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    fixed_point32::create_from_rational(a_raw, b_raw)
  }
  
  // Multiple 2 FixedPoint32 numers
  public fun mul(a: FixedPoint32, b: FixedPoint32): FixedPoint32 {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    let unscaled_res = (a_raw as u128) * (b_raw as u128);
    let scaled_res = (unscaled_res >> 32 as u64);
    fixed_point32::create_from_raw_value(scaled_res)
  }
  
  // Convert a u64 to a FixedPoint32
  public fun from_u64(val: u64): FixedPoint32 {
    fixed_point32::create_from_rational(val, 1)
  }
  
  // A FixedPoint32 represnets 0
  public fun zero(): FixedPoint32 {
    fixed_point32::create_from_rational(0, 1)
  }
  
  // Greater than
  public fun gt(a: FixedPoint32, b: FixedPoint32): bool {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    return a_raw > b_raw
  }

  // greater than equal
  public fun gte(a: FixedPoint32, b: FixedPoint32): bool {
    let a_raw = fixed_point32::get_raw_value(a);
    let b_raw = fixed_point32::get_raw_value(b);
    return a_raw >= b_raw
  }
}
