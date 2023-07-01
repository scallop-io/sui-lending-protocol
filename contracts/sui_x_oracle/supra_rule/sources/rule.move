module supra_rule::rule {
  use sui::math;
  use sui::clock::{Self, Clock};

  use x_oracle::x_oracle::{ Self, XOraclePriceUpdateRequest };
  use x_oracle::price_feed;

  use supra_rule::supra_registry::{Self, SupraRegistry};
  use supra_rule::supra_adaptor;

  use SupraOracle::SupraSValueFeed::OracleHolder;

  const U8_MAX: u16 = 255;
  const U64_MAX: u128 = 18446744073709551615;

  const PRICE_DECIMALS_TOO_LARGE: u64 = 0x11301;
  const SUPRA_PRICE_TOO_OLD: u64 = 0x11304;
  const SUPRA_PRICE_TOO_NEW: u64 = 0x11305;

  struct Rule has drop {}


  public fun set_price<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    supra_oracle: &OracleHolder,
    supra_registry: &SupraRegistry,
    clock: &Clock,
  ) {
    // Make sure the price info object is the registerred one for the coin type
    let pair_id = supra_registry::get_supra_pair_id<CoinType>(supra_registry);

    let (price_value, price_decimals, price_update_time) = supra_adaptor::get_supra_price(supra_oracle, pair_id);

    let formatted_decimals = price_feed::decimals();
    let price_value_with_formatted_decimals = if (price_decimals < formatted_decimals) {
      price_value * math::pow(10, formatted_decimals - price_decimals)
    } else {
      // This should rarely happen, since formatted_decimals is 9 and price_decimals is usually smaller than 8
      price_value / math::pow(10, price_decimals - formatted_decimals)
    };
    assert!(price_value_with_formatted_decimals > 0, PRICE_DECIMALS_TOO_LARGE);

    let now = clock::timestamp_ms(clock) / 1000;
    assert!(price_update_time >= now - 60, SUPRA_PRICE_TOO_OLD);
    assert!(price_update_time <= now + 10, SUPRA_PRICE_TOO_NEW);

    let price_feed = price_feed::new(price_value_with_formatted_decimals, price_update_time);
    x_oracle::set_secondary_price(Rule {}, request, price_feed);
  }
}
