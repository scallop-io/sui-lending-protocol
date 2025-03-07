module switchboard_on_demand_rule::switchboard_adaptor {

  use switchboard::aggregator::{Self, Aggregator};
  use switchboard::decimal;

  public fun get_switchboard_price(
    aggregator: &Aggregator,
  ): (u128, u64) {
    let current_result = aggregator::current_result(aggregator);
    let price_value = decimal::value(aggregator::result(current_result));
    let update_time = aggregator::timestamp_ms(current_result);
    (price_value, update_time)
  }
}
