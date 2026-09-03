/***
This is the helper module for std::fixed_point32
*/
module math::fixed_point32_empower {
  use std::fixed_point32::{Self, FixedPoint32};
  use std::uq32_32::{Self, UQ32_32};
  
  // Add 2 FixedPoint32 numers

// Add 2 UQ32_32 numbers
public fun add(a: UQ32_32, b: UQ32_32): UQ32_32 {
    uq32_32::add(a, b)
}


// Subtract 2 UQ32_32 numbers
public fun sub(a: UQ32_32, b: UQ32_32): UQ32_32 {
    uq32_32::sub(a, b)
}
  
 // Divide 2 UQ32_32 numbers
public fun div(a: UQ32_32, b: UQ32_32): UQ32_32 {
    uq32_32::div(a, b)
}
  
 // Multiply 2 UQ32_32 numbers
public fun mul(a: UQ32_32, b: UQ32_32): UQ32_32 {
    uq32_32::mul(a, b)
}
  
 // Convert a u64 to a UQ32_32
public fun from_u64(val: u64): UQ32_32 {
    uq32_32::from_quotient(val, 1)
}
 // A UQ32_32 representing 0
public fun zero(): UQ32_32 {
    uq32_32::from_int(0)
}
// Greater than
public fun gt(a: UQ32_32, b: UQ32_32): bool {
    uq32_32::gt(a, b)
}
 // Greater than or equal
public fun gte(a: UQ32_32, b: UQ32_32): bool {
    uq32_32::ge(a, b)
}
}