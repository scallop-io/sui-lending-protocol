module x_oracle::x_oracle {
  use std::vector;
  use std::type_name::{TypeName, get};
  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;

  use x_oracle::price_update_policy::{Self, PriceUpdatePolicy, PriceUpdateRequest, PriceUpdatePolicyCap};
  use x_oracle::price_feed::{Self, PriceFeed};

  const PRIMARY_PRICE_NOT_QUALIFIED: u64 = 0;

  struct XOracle has key {
    id: UID,
    primary_price_update_policy: PriceUpdatePolicy,
    secondary_price_update_policy: PriceUpdatePolicy,
    prices: Table<TypeName, PriceFeed>,
    ema_prices: Table<TypeName, PriceFeed>,
  }

  struct XOraclePolicyCap has key, store {
    id: UID,
    primary_price_update_policy_cap: PriceUpdatePolicyCap,
    secondary_price_update_policy_cap: PriceUpdatePolicyCap,
  }

  struct XOraclePriceUpdateRequest<phantom T> {
    primary_price_update_request: PriceUpdateRequest<T>,
    secondary_price_update_request: PriceUpdateRequest<T>,
  }

  // === getters ===

  public fun prices(self: &XOracle): &Table<TypeName, PriceFeed> { &self.prices }

  // === init ===

  public fun new(ctx: &mut TxContext): (XOracle, XOraclePolicyCap) {
    let (primary_price_update_policy, primary_price_update_policy_cap ) = price_update_policy::new(ctx);
    let (secondary_price_update_policy, secondary_price_update_policy_cap ) = price_update_policy::new(ctx);
    let x_oracle = XOracle {
      id: object::new(ctx),
      primary_price_update_policy,
      secondary_price_update_policy,
      prices: table::new(ctx),
      ema_prices: table::new(ctx),
    };
    let x_oracle_update_policy = XOraclePolicyCap {
      id: object::new(ctx),
      primary_price_update_policy_cap,
      secondary_price_update_policy_cap,
    };
    (x_oracle, x_oracle_update_policy)
  }

  // === Price Update Policy ===

  public fun add_primary_price_update_rule<Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::add_rule<Rule>(
      &mut self.primary_price_update_policy,
      &cap.primary_price_update_policy_cap
    );
  }

  public fun add_secondary_price_update_rule<Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::add_rule<Rule>(
      &mut self.secondary_price_update_policy,
      &cap.secondary_price_update_policy_cap
    );
  }

  // === Price Update ===

  public fun price_update_request<T>(
    self: &XOracle,
  ): XOraclePriceUpdateRequest<T> {
    let primary_price_update_request = price_update_policy::new_request<T>(&self.primary_price_update_policy);
    let secondary_price_update_request = price_update_policy::new_request<T>(&self.secondary_price_update_policy);
    XOraclePriceUpdateRequest {
      primary_price_update_request,
      secondary_price_update_request,
    }
  }

  public fun set_primary_price<T, Rule: drop>(
    rule: Rule,
    request: &mut XOraclePriceUpdateRequest<T>,
    price_feed: PriceFeed,
  ) {
    price_update_policy::add_price_feed(rule, &mut request.primary_price_update_request, price_feed);
  }

  public fun set_secondary_price<T, Rule: drop>(
    rule: Rule,
    request: &mut XOraclePriceUpdateRequest<T>,
    price_feed: PriceFeed,
  ) {
    price_update_policy::add_price_feed(rule, &mut request.secondary_price_update_request, price_feed);
  }

  public fun confirm_price_update_request<T>(
    self: &mut XOracle,
    request: XOraclePriceUpdateRequest<T>
  ) {
    let XOraclePriceUpdateRequest { primary_price_update_request, secondary_price_update_request  } = request;
    let primary_price_feeds = price_update_policy::confirm_request(
      primary_price_update_request,
      &self.primary_price_update_policy
    );
    let secondary_price_feeds = price_update_policy::confirm_request(
      secondary_price_update_request,
      &self.secondary_price_update_policy
    );
    let current_price_feed = table::borrow_mut(&mut self.prices, get<T>());
    let price_feed = determine_price(primary_price_feeds, secondary_price_feeds);
    *current_price_feed = price_feed;
  }

  fun determine_price(
    primary_price_feeds: vector<PriceFeed>,
    secondary_price_feeds: vector<PriceFeed>,
  ): PriceFeed {
    // current we only have one primary price feed
    let primary_price_feed = vector::pop_back(&mut primary_price_feeds);
    let secondary_price_feed_num = vector::length(&secondary_price_feeds);

    // We require the primary price feed to be confirmed by at least half of the secondary price feeds
    let required_secondary_match_num = (secondary_price_feed_num + 1) / 2;
    let matched: u64 = 0;
    let i = 0;
    while (i < secondary_price_feed_num) {
      let secondary_price_feed = vector::pop_back(&mut secondary_price_feeds);
      if (price_feed_match(primary_price_feed, secondary_price_feed)) {
        matched == matched + 1;
      };
      i = i + 1;
    };
    assert!(matched >= required_secondary_match_num, PRIMARY_PRICE_NOT_QUALIFIED);

    // Use the primary price feed as the final price feed
    primary_price_feed
  }

  // Check if two price feeds are within a reasonable range
  // If price_feed1 is within 1% away from price_feed2, then they are considered to be matched
  fun price_feed_match(
    price_feed1: PriceFeed,
    price_feed2: PriceFeed,
  ): bool {
    let value1 = price_feed::value(&price_feed1);
    let value2 = price_feed::value(&price_feed2);

    let scale = 1000;
    let reasonable_diff_percent = 1;
    let reasonable_diff = reasonable_diff_percent * scale / 100;
    let diff = value1 * scale / value2;
    diff <= scale + reasonable_diff && diff >= scale - reasonable_diff
  }
}
