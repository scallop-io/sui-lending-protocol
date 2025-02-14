module pyth_rule::pyth_adaptor {

  use sui::clock::{Self, Clock};

  use pyth::pyth;
  use pyth::price::{Self, Price};
  use pyth::i64;
  use pyth::state::{State as PythState};
  use pyth::price_info::{PriceInfoObject};

  friend pyth_rule::rule;

  use pyth_rule::pyth_registry::{Self, PythFeedData};

  const U8_MAX: u64 = 255;

  const PYTH_PRICE_DECIMALS_TOO_LARGE: u64 = 0x11201;
  const PYTH_PRICE_TOO_OLD: u64 = 0x11202;
  const PYTH_PRICE_TOO_NEW: u64 = 0x11203;
  const PYTH_PRICE_CONF_TOO_LARGE: u64 = 0x11299;

  public(friend) fun get_pyth_price(
    pyth_state: &PythState,
    pyth_price_info_object: &PriceInfoObject,
    pyth_feed_data: &PythFeedData,
    clock: &Clock,
  ): (u64, u64, u8, u64) {
    let pyth_price = pyth::get_price(pyth_state, pyth_price_info_object, clock);
    let price_value = price::get_price(&pyth_price);
    let price_value = i64::get_magnitude_if_positive(&price_value);
    let price_conf = price::get_conf(&pyth_price);
    let price_decimals = price::get_expo(&pyth_price);
    let price_decimals = i64::get_magnitude_if_negative(&price_decimals);
    // For price value, the decimals could definitely fit in a u8, otherwise there's a bug
    assert!(price_decimals <= U8_MAX, PYTH_PRICE_DECIMALS_TOO_LARGE);
    // Make sure price is fresh
    assert_price_not_stale(&pyth_price, clock);
    // Make sure price confidence is within range
    let price_conf_tolerance = pyth_registry::price_conf_tolerance(pyth_feed_data);
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);
    let price_decimals = (price_decimals as u8);
    let now = clock::timestamp_ms(clock) /1000;
    (price_value, price_conf, price_decimals, now)
  }

  fun assert_price_not_stale(price: &Price, clock: &Clock) {
    let price_updated_time  = price::get_timestamp(price);
    let now = clock::timestamp_ms(clock) /1000;
    // Make sure price is updated within 30 seconds
    assert!(price_updated_time >= now - 30, PYTH_PRICE_TOO_OLD);
  }

  fun assert_price_conf_within_range(price_value: u64, price_conf: u64, price_conf_tolerance: u64) {
    // Check price confidence is within range
    let base = 10000;
    let price_conf_range = price_conf_tolerance * base * 100 / pyth_registry::conf_tolerance_denominator(); // multiply by 100, to make it in percentage format
    let price_conf_diff = (price_conf * base * 100 as u128) / (price_value as u128);
    assert!((price_conf_diff as u64) <= price_conf_range, PYTH_PRICE_CONF_TOO_LARGE);
  }
}
