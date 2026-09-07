
module protocol::price {
use std::uq32_32::{Self, UQ32_32};
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
  ): UQ32_32 {
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

    uq32_32::from_quotient(price_value, std::u64::pow(10, price_decimal))
  }
}
