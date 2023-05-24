module x_oracle::price_feed {

  // We fix the number of price decimals to 9
  const PRICE_DECIMALS: u8 = 9;

  struct PriceFeed has store, copy, drop {
    value: u64,
    last_updated: u64,
  }

  public fun new(
    value: u64,
    last_updated: u64
  ): PriceFeed {
    PriceFeed { value, last_updated }
  }

  public fun value(self: &PriceFeed): u64 { self.value }
  public fun decimals(): u8 { PRICE_DECIMALS }
  public fun last_updated(self: &PriceFeed): u64 { self.last_updated }

  #[test_only]
  public fun update_price_feed(price_feed: &mut PriceFeed, value: u64, last_updated: u64) {
    price_feed.value = value;
    price_feed.last_updated = last_updated;
  }
}
