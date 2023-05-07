module protocol::price {
  use std::fixed_point32::{Self, FixedPoint32};
  use std::type_name::TypeName;
  use sui::table;
  use sui::math;

  use x_oracle::x_oracle::{Self, XOracle};
  use x_oracle::price_feed::{Self, PriceFeed};

  public fun get_price(
    x_oracle: &XOracle,
    type: TypeName,
  ): FixedPoint32 {
    let prices = x_oracle::prices(x_oracle);
    let price = table::borrow<TypeName, PriceFeed>(prices, type);
    let price_decimal = price_feed::decimals();
    let price_value = price_feed::value(price);
    fixed_point32::create_from_rational(price_value, math::pow(10, price_decimal))
  }
}
