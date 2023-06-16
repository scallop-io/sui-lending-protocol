module supra_rule::supra_adaptor {

  use SupraOracle::SupraSValueFeed::{Self, OracleHolder};

  const U8_MAX: u16 = 255;
  const U64_MAX: u128 = 18446744073709551615;

  /// errors
  const PRICE_DECIMALS_TOO_LARGE: u64 = 0x11301;
  const PRICE_VALUE_TOO_LARGE: u64 = 0x11302;
  const TIMESTAMP_TOO_LARGE: u64 = 0x11303;

  public fun get_supra_price(
    supra_oracle: &OracleHolder,
    pair_id: u32,
  ): (u64, u8, u64) {
    let (price_value, price_decimals, timestamp, _) = SupraSValueFeed::get_price(supra_oracle, pair_id);

    assert!(price_decimals <= U8_MAX, PRICE_DECIMALS_TOO_LARGE);
    let price_decimals = (price_decimals as u8);

    assert!(price_value <= U64_MAX, PRICE_VALUE_TOO_LARGE);
    let price_value = (price_value as u64);

    // Supra timestamp is in milliseconds, but XOracle timestamp is in seconds
    let price_update_time = timestamp / 1000;
    assert!(price_update_time <= U64_MAX, TIMESTAMP_TOO_LARGE);
    let price_update_time = (price_update_time as u64);

    (price_value, price_decimals, price_update_time)
  }
}
