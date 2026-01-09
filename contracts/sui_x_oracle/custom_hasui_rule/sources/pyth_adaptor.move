module custom_hasui_rule::pyth_adaptor;

use custom_hasui_rule::oracle_config::{Self, OracleConfig};
use pyth::i64;
use pyth::price::{Self, Price};
use pyth::price_info::PriceInfoObject;
use pyth::pyth;
use pyth::state::State as PythState;
use sui::clock::{Self, Clock};
use decimal::decimal::{Self, Decimal};

const U8_MAX: u64 = 255;

const PYTH_PRICE_DECIMALS_TOO_LARGE: u64 = 0x1;
const PYTH_PRICE_TOO_OLD: u64 = 0x2;
const PYTH_PRICE_CONF_TOO_LARGE: u64 = 0x3;

public(package) fun get_pyth_price(
    pyth_state: &PythState,
    pyth_price_info_object: &PriceInfoObject,
    oracle_config: &OracleConfig,
    clock: &Clock,
): (u64, u64, u8, u64) {
    let pyth_price = pyth::get_price(pyth_state, pyth_price_info_object, clock);
    let price_value = price::get_price(&pyth_price);
    let price_value = i64::get_magnitude_if_positive(&price_value);
    let price_conf = price::get_conf(&pyth_price);
    let price_decimals = price::get_expo(&pyth_price);
    let price_decimals = i64::get_magnitude_if_negative(&price_decimals);
    // For price value, the decimals could definitely fit in a u8
    assert!(price_decimals <= U8_MAX, PYTH_PRICE_DECIMALS_TOO_LARGE);
    // Make sure price is fresh
    assert_price_not_stale(&pyth_price, clock);
    // Make sure price confidence is within range
    let price_conf_tolerance = oracle_config::price_conf_tolerance(oracle_config);
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);
    let price_decimals = (price_decimals as u8);
    let now = clock::timestamp_ms(clock) /1000;
    (price_value, price_conf, price_decimals, now)
}

fun assert_price_not_stale(price: &Price, clock: &Clock) {
    let price_updated_time = price::get_timestamp(price);
    let now = clock::timestamp_ms(clock) /1000;
    // Make sure price is updated within 30 seconds
    assert!(price_updated_time >= now - 30, PYTH_PRICE_TOO_OLD);
}

fun assert_price_conf_within_range(price_value: u64, price_conf: u64, price_conf_tolerance: Decimal) {
    let price_value_in_decimal = decimal::from(price_value);
    let price_conf_in_decimal = decimal::from(price_conf);
    let price_conf_diff = price_conf_in_decimal.div(price_value_in_decimal);
    assert!(price_conf_diff.le(price_conf_tolerance), PYTH_PRICE_CONF_TOO_LARGE);
}

#[test]
fun assert_price_within_confidence_test() {
    let price_value = 100_000_000; // scale with 10^8. = $1
    let price_conf = 1_000_000; // scale with 10^8. = $0.01
    let price_conf_tolerance = decimal::from_bps(100); // in bps. = 1%
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);

    let price_value = 100_000_000; // scale with 10^8. = $1
    let price_conf = 2_000_000; // scale with 10^8. = $0.02
    let price_conf_tolerance = decimal::from_bps(200); // in bps. = 2%
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);

    let price_value = 100_000_000; // scale with 10^8. = $1
    let price_conf = 2_500_000; // scale with 10^8. = $0.025
    let price_conf_tolerance = decimal::from_bps(250); // in bps. = 2.5%
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);
}

#[test, expected_failure(abort_code = PYTH_PRICE_CONF_TOO_LARGE)]
fun assert_price_out_confidence_err_test() {
    let price_value = 100_000_000; // scale with 10^8. = $1
    let price_conf = 1_500_000; // scale with 10^8. = $0.015
    let price_conf_tolerance = decimal::from_bps(100); // in bps. = 1%
    assert_price_conf_within_range(price_value, price_conf, price_conf_tolerance);
}