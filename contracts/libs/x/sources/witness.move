module x::witness {
  use sui::package::{Self, Publisher};

  const EInvalidPublisher: u64 = 0x21101;

  /// Witness generator
  struct WitnessGenerator<phantom T> has store {}

  /// Delegated witness of a generic type. The type `T` can be any type.
  struct Witness<phantom T> has drop {}

  /// Creates a delegated witness from package publisher.
  public fun from_publisher<T>(publisher: &Publisher): Witness<T> {
    assert_publisher<T>(publisher);
    Witness {}
  }

  /// Create a new `WitnessGenerator` from delegated witness
  public fun to_generator<T>(_: Witness<T>): WitnessGenerator<T> {
    WitnessGenerator {}
  }

  /// Get a delegated witness from `WitnessGenerator`
  public fun from_generator<T>(generator: WitnessGenerator<T>): Witness<T> {
    let WitnessGenerator { } = generator;
    Witness {}
  }

  /// Asserts that `Publisher` is of type `T`
  /// Panics if `Publisher` is mismatched
  public fun assert_publisher<T>(pub: &Publisher) {
    assert!(package::from_package<T>(pub), EInvalidPublisher);
  }
}
