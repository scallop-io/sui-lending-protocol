module supra_rule::rule {
  use sui::clock::Clock;
  use sui::math;

  use x_oracle::x_oracle::{ Self, XOraclePriceUpdateRequest };
  use x_oracle::price_feed;

  use supra_rule::supra_registry::{Self, SupraRegistry};

  use SupraOracle::SupraSValueFeed::{Self, OracleHolder};

  const U8_MAX: u16 = 255;
  const U64_MAX: u128 = 18446744073709551615;

  const PRICE_DECIMALS_TOO_LARGE: u64 = 0;
  const PRICE_VALUE_TOO_LARGE: u64 = 1;
  const TIMESTAMP_TOO_LARGE: u64 = 2;

  struct Rule has drop {}


  public fun set_price<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    supra_oracle: &mut OracleHolder,
    supra_registry: &SupraRegistry,
    clock: &Clock,
  ) {
    // Make sure the price info object is the registerred one for the coin type
    let pair_id = supra_registry::get_supra_pair_id<CoinType>(supra_registry);
    let (price_value, price_decimals, timestamp, _) = SupraSValueFeed::get_price(supra_oracle, pair_id);

    assert!(price_decimals <= U8_MAX, PRICE_DECIMALS_TOO_LARGE);
    let price_decimals = (price_decimals as u8);

    assert!(price_value <= U64_MAX, PRICE_VALUE_TOO_LARGE);
    let price_value = (price_value as u64);

    let formatted_decimals = price_feed::decimals();
    let price_value_with_formatted_decimals = if (price_decimals < formatted_decimals) {
      price_value * math::pow(10, formatted_decimals - price_decimals)
    } else {
      // This should rarely happen, since formatted_decimals is 9 and price_decimals is usually smaller than 8
      price_value / math::pow(10, price_decimals - formatted_decimals)
    };
    assert!(price_value_with_formatted_decimals > 0, PRICE_DECIMALS_TOO_LARGE);

    assert!(timestamp <= U64_MAX, TIMESTAMP_TOO_LARGE);
    let timestamp= (timestamp as u64);

    let price_feed = price_feed::new(price_value_with_formatted_decimals, timestamp);
    x_oracle::set_primary_price(Rule {}, request, price_feed);
  }
}
