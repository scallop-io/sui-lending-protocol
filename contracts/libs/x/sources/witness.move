module x::witness {
  use sui::package::{Self, Publisher};

  const EInvalidPublisher: u64 = 0x21101;

  /// Collection witness generator
  struct WitnessGenerator<phantom T> has store {}

  /// Delegated witness of a generic type. The type `T` can be any type.
  struct Witness<phantom T> has copy, drop {}

  /// Create a new `WitnessGenerator` from delegated witness
  public fun generator_delegated<T>(
    _witness: Witness<T>,
  ): WitnessGenerator<T> {
    WitnessGenerator {}
  }

  /// Creates a delegated witness from a package publisher.
  public fun from_publisher<T>(publisher: &Publisher): Witness<T> {
    assert_publisher<T>(publisher);
    Witness {}
  }

  /// Delegate a collection generic witness
  public fun delegate<T>(_generator: &WitnessGenerator<T>): Witness<T> {
    Witness {}
  }

  /// Asserts that `Publisher` is of type `T`
  /// Panics if `Publisher` is mismatched
  public fun assert_publisher<T>(pub: &Publisher) {
    assert!(package::from_package<T>(pub), EInvalidPublisher);
  }
}
