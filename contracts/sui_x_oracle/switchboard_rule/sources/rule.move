module switchboard_rule::rule {

  use sui::math;
  use sui::clock::{Self, Clock};
  use switchboard_std::aggregator::Aggregator;

  use x_oracle::x_oracle::{Self, XOraclePriceUpdateRequest};
  use x_oracle::price_feed;

  use switchboard_rule::switchboard_adaptor;
  use switchboard_rule::switchboard_registry::{Self, SwitchboardRegistry};

  const U64_MAX: u128 = 18446744073709551615;

  const ERR_BAD_SWITCHBOARD_PRICE: u64 = 0x11401;
  const SWITCHBOARD_PRICE_TOO_OLD: u64 = 0x11402;
  const SWITCHBOARD_PRICE_TOO_NEW: u64 = 0x11403;


  struct Rule has drop {}

  public fun set_price<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    aggregator: &Aggregator,
    switchboard_registry: &SwitchboardRegistry,
    clock: &Clock
  ) {
    // Make sure the aggregator is registered in the switchboard registry for the coin type
    switchboard_registry::assert_switchboard_aggregator<CoinType>(switchboard_registry, aggregator);

    let (price_value, price_decimals, updated_time) = switchboard_adaptor::get_switchboard_price(aggregator);

    let formatted_decimals: u8 = price_feed::decimals();
    let price_value_formatted = if (price_decimals < formatted_decimals) {
      price_value * (math::pow(10, formatted_decimals - price_decimals) as u128)
    } else {
      price_value / (math::pow(10, price_decimals - formatted_decimals) as u128)
    };
    assert!(price_value_formatted > 0 && price_value_formatted < U64_MAX, ERR_BAD_SWITCHBOARD_PRICE);
    assert_price_not_stale(updated_time, clock);
    let price_value_formatted = (price_value_formatted as u64);
    let price_feed = price_feed::new(price_value_formatted, updated_time);
    x_oracle::set_secondary_price(Rule {}, request, price_feed);
  }

  fun assert_price_not_stale(updated_time: u64, clock: &Clock) {
    let now = clock::timestamp_ms(clock) / 1000;
    assert!(updated_time >= now - 60, SWITCHBOARD_PRICE_TOO_OLD);
    assert!(updated_time <= now + 10, SWITCHBOARD_PRICE_TOO_NEW);
  }
}
