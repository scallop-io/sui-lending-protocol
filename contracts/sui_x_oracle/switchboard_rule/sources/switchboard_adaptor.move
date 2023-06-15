module switchboard_rule::switchboard_adaptor {

  use switchboard_std::aggregator::{Self, Aggregator};
  use switchboard_std::math as switchboard_math;

  const ERR_NEGATIVE_SWITCHBOARD_PRICE: u64 = 0x11404;

  public fun get_switchboard_price(
    aggregator: &Aggregator,
  ): (u128, u8, u64) {
    let (price, updated_time) = aggregator::latest_value(aggregator);
    let (price_value, price_decimals, negative) = switchboard_math::unpack(price);
    assert!(negative == false, ERR_NEGATIVE_SWITCHBOARD_PRICE);

    (price_value, price_decimals, updated_time)
  }
}
