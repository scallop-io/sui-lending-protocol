module custom_afsui_rule::rule;

use afsui::afsui::AFSUI;
use custom_afsui_rule::oracle_config::{Self, OracleConfig};
use custom_afsui_rule::pyth_adaptor;
use decimal::decimal;
use lsd::staked_sui_vault::{sui_to_afsui_exchange_rate, StakedSuiVault};
use pyth::price_info::PriceInfoObject;
use pyth::state::State as PythState;
use safe::safe::Safe;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use x_oracle::price_feed;
use x_oracle::x_oracle::{Self, XOraclePriceUpdateRequest};

const PYTH_PRICE_DECIMALS_TOO_LARGE: u64 = 0x1;
const INVALID_EXCHANGE_RATE_RANGE_ERR: u64 = 0x2;

public struct Rule has drop {}

public fun set_price_as_primary(
    request: &mut XOraclePriceUpdateRequest<AFSUI>,
    pyth_state: &PythState,
    pyth_price_info_object: &PriceInfoObject,
    oracle_config: &OracleConfig,
    af_staked_sui_vault: &StakedSuiVault,
    af_safe: &Safe<TreasuryCap<AFSUI>>,
    clock: &Clock,
) {
    let (price_value_with_formatted_decimals, updated_time) = get_price(
        pyth_state,
        pyth_price_info_object,
        oracle_config,
        af_staked_sui_vault,
        af_safe,
        clock,
    );

    let price_feed = price_feed::new(price_value_with_formatted_decimals, updated_time);
    x_oracle::set_primary_price(Rule {}, request, price_feed);
}

public fun set_price_as_secondary(
    request: &mut XOraclePriceUpdateRequest<AFSUI>,
    pyth_state: &PythState,
    pyth_price_info_object: &PriceInfoObject,
    oracle_config: &OracleConfig,
    af_staked_sui_vault: &StakedSuiVault,
    af_safe: &Safe<TreasuryCap<AFSUI>>,
    clock: &Clock,
) {
    let (price_value_with_formatted_decimals, updated_time) = get_price(
        pyth_state,
        pyth_price_info_object,
        oracle_config,
        af_staked_sui_vault,
        af_safe,
        clock,
    );

    let price_feed = price_feed::new(price_value_with_formatted_decimals, updated_time);
    x_oracle::set_secondary_price(Rule {}, request, price_feed);
}

fun get_price(
    pyth_state: &PythState,
    pyth_price_info_object: &PriceInfoObject,
    oracle_config: &OracleConfig,
    af_staked_sui_vault: &StakedSuiVault,
    af_safe: &Safe<TreasuryCap<AFSUI>>,
    clock: &Clock,
): (u64, u64) {
    // Make sure the price info object is the registerred one for the coin type
    oracle_config::assert_pyth_price_info_object(oracle_config, pyth_price_info_object);

    // sui_to_afsui_exchange_rate is on the scale of 10^18
    let sui_to_afsui_exchange_rate = sui_to_afsui_exchange_rate(af_staked_sui_vault, af_safe);
    let sui_to_afsui_exchange_rate = decimal::from_scaled_val((sui_to_afsui_exchange_rate as u256));

    let (price_value, _, price_decimals, updated_time) = pyth_adaptor::get_pyth_price(
        pyth_state,
        pyth_price_info_object,
        oracle_config,
        clock,
    );

    // Check exchange rate is within range
    assert!(
        sui_to_afsui_exchange_rate.le(decimal::from_percent(112)),
        INVALID_EXCHANGE_RATE_RANGE_ERR,
    ); // < 112%
    assert!(
        sui_to_afsui_exchange_rate.ge(decimal::from_percent(100)),
        INVALID_EXCHANGE_RATE_RANGE_ERR,
    ); // > 100%

    let price_value = decimal::from(price_value);
    let price_value = decimal::mul(price_value, sui_to_afsui_exchange_rate);
    let price_value = decimal::floor(price_value);

    let formatted_decimals = price_feed::decimals();
    let price_value_with_formatted_decimals = if (price_decimals < formatted_decimals) {
        price_value * std::u64::pow(10, formatted_decimals - price_decimals)
    } else {
        // This should rarely happen, since formatted_decimals is 9 and price_decimals is usually smaller than 8
        price_value / std::u64::pow(10, price_decimals - formatted_decimals)
    };
    assert!(price_value_with_formatted_decimals > 0, PYTH_PRICE_DECIMALS_TOO_LARGE);
    (price_value_with_formatted_decimals, updated_time)
}
