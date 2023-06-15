module protocol::price {
  use std::fixed_point32::{Self, FixedPoint32};
  use std::type_name::TypeName;
  use sui::table;
  use sui::math;
  use sui::clock::{Self, Clock};

  use x_oracle::x_oracle::{Self, XOracle};
  use x_oracle::price_feed::{Self, PriceFeed};

  use protocol::error;

  public fun get_price(
    x_oracle: &XOracle,
    type: TypeName,
    clock: &Clock,
  ): FixedPoint32 {
    let prices = x_oracle::prices(x_oracle);

    // Check if price exists
    assert!(table::contains(prices, type), error::oracle_price_not_found_error());

    let price = table::borrow<TypeName, PriceFeed>(prices, type);
    let price_decimal = price_feed::decimals();
    let price_value = price_feed::value(price);
    let last_updated = price_feed::last_updated(price);

    // Check if price is stale
    let now = clock::timestamp_ms(clock) / 1000;
    assert!(now == last_updated, error::oracle_stale_price_error());
    assert!(price_value > 0, error::oracle_zero_price_error());

    fixed_point32::create_from_rational(price_value, math::pow(10, price_decimal))
  }
}
