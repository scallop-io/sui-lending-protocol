module switchboard_on_demand_rule::switchboard_adaptor {

  use switchboard::aggregator::{Self, Aggregator};
  use switchboard::decimal;

  const ERR_NEGATIVE_SWITCHBOARD_PRICE: u64 = 0x1;

  public fun get_switchboard_price(
    aggregator: &Aggregator,
  ): (u128, u64) {
    let current_result = aggregator::current_result(aggregator);
    let decimal_result = aggregator::result(current_result);
    let price_value = decimal::value(decimal_result);
    assert!(decimal::neg(decimal_result) == false, ERR_NEGATIVE_SWITCHBOARD_PRICE);
    let update_time = aggregator::timestamp_ms(current_result) / 1000;
    (price_value, update_time)
  }
}
