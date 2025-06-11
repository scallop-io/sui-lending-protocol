module custom_afsui_rule::oracle_config;

use decimal::decimal::{Self, Decimal};
use pyth::price_info::PriceInfoObject;

const ERR_INVALID_PYTH_OBJECT: u64 = 0x1;
const ERR_INVALID_CAP: u64 = 0x2;
const ERR_INVALID_CONF_TOLERANCE: u64 = 0x3;
const ERR_CONFIG_HAVENT_INITIALIZED: u64 = 0x4;

const CONF_TOLERANCE_DENOMINATOR: u64 = 10_000;

public struct OracleConfig has key {
    id: UID,
    feed_id: Option<ID>,
    conf_tolerance: Option<u64>,
    min_exchange_rate: Decimal,
    max_exchange_rate: Decimal,
}

public struct OracleAdminCap has key, store {
    id: UID,
    parent: ID,
}

public fun conf_tolerance_denominator(): u64 {
    CONF_TOLERANCE_DENOMINATOR
}

fun init(ctx: &mut TxContext) {
    let oracle_config = OracleConfig {
        id: object::new(ctx),
        feed_id: option::none(),
        conf_tolerance: option::none(),
        // Default exchange rate constraints, can be updated later
        min_exchange_rate: decimal::from_percent(100), // 100%
        max_exchange_rate: decimal::from_percent(112), // 112%
    };
    let oracle_cap = OracleAdminCap {
        id: object::new(ctx),
        parent: object::id(&oracle_config),
    };
    transfer::share_object(oracle_config);
    transfer::transfer(oracle_cap, tx_context::sender(ctx));
}

public fun price_feed_id(oracle_config: &OracleConfig): ID {
    assert!(option::is_some(&oracle_config.feed_id), ERR_CONFIG_HAVENT_INITIALIZED);
    *option::borrow(&oracle_config.feed_id)
}

public fun price_conf_tolerance(oracle_config: &OracleConfig): u64 {
    assert!(option::is_some(&oracle_config.conf_tolerance), ERR_CONFIG_HAVENT_INITIALIZED);
    *option::borrow(&oracle_config.conf_tolerance)
}

public fun min_exchange_rate(oracle_config: &OracleConfig): Decimal {
    oracle_config.min_exchange_rate
}

public fun max_exchange_rate(oracle_config: &OracleConfig): Decimal {
    oracle_config.max_exchange_rate
}

public entry fun update_oracle_config(
    oracle_config: &mut OracleConfig,
    oracle_cap: &OracleAdminCap,
    pyth_info_object: &PriceInfoObject,
    pyth_feed_confidence_tolerance: u64, // per 10,000. so 1 = 0.01%
) {
    assert!(
        pyth_feed_confidence_tolerance <= conf_tolerance_denominator(),
        ERR_INVALID_CONF_TOLERANCE,
    );
    assert!(object::id(oracle_config) == oracle_cap.parent, ERR_INVALID_CAP);

    oracle_config.feed_id = option::some(object::id(pyth_info_object));
    oracle_config.conf_tolerance = option::some(pyth_feed_confidence_tolerance);
}

public entry fun update_exchange_rate_constraint(
    oracle_config: &mut OracleConfig,
    oracle_cap: &OracleAdminCap,
    min_exchange_rate_bps: u64, // in basis points, so 10_000 = 100%, 1 = 0.01%
    max_exchange_rate_bps: u64, // in basis points, so 10_000 = 100%, 1 = 0.01%
) {
    assert!(object::id(oracle_config) == oracle_cap.parent, ERR_INVALID_CAP);
    oracle_config.min_exchange_rate = decimal::from_bps(min_exchange_rate_bps);
    oracle_config.max_exchange_rate = decimal::from_bps(max_exchange_rate_bps);
}

public fun assert_pyth_price_info_object(
    oracle_config: &OracleConfig,
    price_info_object: &PriceInfoObject,
) {
    assert!(object::id(price_info_object) == price_feed_id(oracle_config), ERR_INVALID_PYTH_OBJECT);
}
