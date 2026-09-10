#[test_only]
module x_oracle::test_utils {
    use x_oracle::x_oracle::{Self, XOracle};
    use x_oracle::price_feed::{Self, PriceFeed};
    use sui::clock::{Self, Clock};
    use sui::table;
    use sui::math;
  use std::uq32_32::{Self, UQ32_32};
    use std::type_name::{Self, TypeName};

    public fun get_price<T>(
        x_oracle: &XOracle,
        clock: &Clock,
    ): UQ32_32 {
        let prices = x_oracle::prices(x_oracle);

        let coin_type = type_name::  with_defining_ids<T>();
        assert!(table::contains(prices, coin_type), 0); // price feed not found

        let price = table::borrow<TypeName, PriceFeed>(prices, coin_type);
        let price_decimal = price_feed::decimals();
        let price_value = price_feed::value(price);
        let last_updated = price_feed::last_updated(price);

        let now = clock::timestamp_ms(clock) / 1000;
        assert!(now == last_updated, 0); // price stale
        assert!(price_value > 0, 0); // price error

        uq32_32::from_quotient(price_value, std::u64::pow(10, price_decimal))
    }
}