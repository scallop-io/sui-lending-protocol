module pyth_rule::rule {

  use sui::clock::Clock;
  use sui::math;

  use pyth::state::State as PythState;
  use pyth::price_info::PriceInfoObject;

  use x_oracle::x_oracle::{ Self, XOraclePriceUpdateRequest };
  use x_oracle::price_feed;

  use pyth_rule::pyth_adaptor;
  use pyth_rule::pyth_registry::{Self, PythRegistry};

  const U8_MAX: u64 = 255;

  const PYTH_PRICE_DECIMALS_TOO_LARGE: u64 = 0x11204;

  struct Rule has drop {}


  public fun set_price<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    pyth_state: &PythState,
    pyth_price_info_object: &mut PriceInfoObject,
    pyth_registry: &PythRegistry,
    clock: &Clock,
  ) {
    // Make sure the price info object is the registerred one for the coin type
    pyth_registry::assert_pyth_price_info_object<CoinType>(pyth_registry, pyth_price_info_object);

    let (price_value, _, price_decimals, updated_time) = pyth_adaptor::get_pyth_price(
      pyth_state,
      pyth_price_info_object,
      clock
    );
    let formatted_decimals = price_feed::decimals();
    let price_value_with_formatted_decimals = if (price_decimals < formatted_decimals) {
      price_value * math::pow(10, formatted_decimals - price_decimals)
    } else {
      // This should rarely happen, since formatted_decimals is 9 and price_decimals is usually smaller than 8
      price_value / math::pow(10, price_decimals - formatted_decimals)
    };
    assert!(price_value_with_formatted_decimals > 0, PYTH_PRICE_DECIMALS_TOO_LARGE);
    let price_feed = price_feed::new(price_value_with_formatted_decimals, updated_time);
    x_oracle::set_primary_price(Rule {}, request, price_feed);
  }
}
