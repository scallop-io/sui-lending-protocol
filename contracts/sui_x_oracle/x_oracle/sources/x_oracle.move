module x_oracle::x_oracle {
  use std::vector;
  use std::type_name::{TypeName, get};
  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::package;

  use x_oracle::price_update_policy::{Self, PriceUpdatePolicy, PriceUpdateRequest, PriceUpdatePolicyCap};
  use x_oracle::price_feed::{Self, PriceFeed};

  const PRIMARY_PRICE_NOT_QUALIFIED: u64 = 720;
  const ONLY_SUPPORT_ONE_PRIMARY: u64 = 721;

  struct X_ORACLE has drop {}

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

  #[allow(lint(share_owned))]
  fun init(otw: X_ORACLE, ctx: &mut TxContext) {
    let (x_oracle, x_oracle_policy_cap) = new(ctx);
    init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, ctx);
    transfer::share_object(x_oracle);
    transfer::transfer(x_oracle_policy_cap, tx_context::sender(ctx));
    package::claim_and_keep(otw, ctx);
  }

  fun new(ctx: &mut TxContext): (XOracle, XOraclePolicyCap) {
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

  public fun init_rules_df_if_not_exist(policy_cap: &XOraclePolicyCap, x_oracle: &mut XOracle, ctx: &mut TxContext) {
    price_update_policy::init_rules_df_if_not_exist(&policy_cap.primary_price_update_policy_cap, &mut x_oracle.primary_price_update_policy, ctx);
    price_update_policy::init_rules_df_if_not_exist(&policy_cap.secondary_price_update_policy_cap, &mut x_oracle.secondary_price_update_policy, ctx);
  }

  // === Price Update Policy ===

  public fun add_primary_price_update_rule_v2<CoinType, Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::add_rule_v2<CoinType, Rule>(
      &mut self.primary_price_update_policy,
      &cap.primary_price_update_policy_cap
    );
  }

  public fun remove_primary_price_update_rule_v2<CoinType, Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::remove_rule_v2<CoinType, Rule>(
      &mut self.primary_price_update_policy,
      &cap.primary_price_update_policy_cap
    );
  }

  public fun add_primary_price_update_rule<Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::add_rule<Rule>(
      &mut self.primary_price_update_policy,
      &cap.primary_price_update_policy_cap
    );
  }

  public fun remove_primary_price_update_rule<Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::remove_rule<Rule>(
      &mut self.primary_price_update_policy,
      &cap.primary_price_update_policy_cap
    );
  }

  public fun add_secondary_price_update_rule_v2<CoinType, Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::add_rule_v2<CoinType, Rule>(
      &mut self.secondary_price_update_policy,
      &cap.secondary_price_update_policy_cap
    );
  }

  public fun remove_secondary_price_update_rule_v2<CoinType, Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::remove_rule_v2<CoinType, Rule>(
      &mut self.secondary_price_update_policy,
      &cap.secondary_price_update_policy_cap
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

  public fun remove_secondary_price_update_rule<Rule: drop>(
    self: &mut XOracle,
    cap: &XOraclePolicyCap,
  ) {
    price_update_policy::remove_rule<Rule>(
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
    request: XOraclePriceUpdateRequest<T>,
    clock: &Clock,
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
    let coin_type = get<T>();
    if (!table::contains(&self.prices, coin_type)) {
      table::add(&mut self.prices, coin_type, price_feed::new(0,0));
    };
    let price_feed = determine_price(primary_price_feeds, secondary_price_feeds);

    let current_price_feed = table::borrow_mut(&mut self.prices, get<T>());

    let now = clock::timestamp_ms(clock) / 1000;
    let new_price_feed = price_feed::new(
      price_feed::value(&price_feed),
      now
    );
    *current_price_feed = new_price_feed;
  }

  fun determine_price(
    primary_price_feeds: vector<PriceFeed>,
    secondary_price_feeds: vector<PriceFeed>,
  ): PriceFeed {
    // current we only support one primary price feed
    assert!(vector::length(&primary_price_feeds) == 1, ONLY_SUPPORT_ONE_PRIMARY);
    let primary_price_feed = vector::pop_back(&mut primary_price_feeds);
    let secondary_price_feed_num = vector::length(&secondary_price_feeds);

    // We require the primary price feed to be confirmed by at least half of the secondary price feeds
    let required_secondary_match_num = (secondary_price_feed_num + 1) / 2;
    let matched: u64 = 0;
    let i = 0;
    while (i < secondary_price_feed_num) {
      let secondary_price_feed = vector::pop_back(&mut secondary_price_feeds);
      if (price_feed_match(primary_price_feed, secondary_price_feed)) {
        matched = matched + 1;
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

  #[test]
  public fun test_feed_match() {
    let feed1 = price_feed::new(10100000, 1);
    let feed2 = price_feed::new(10000000, 1);
    let primary_feeds = vector::singleton(feed1);
    let secondary_feeds = vector::singleton(feed2);
    let res = determine_price(primary_feeds, secondary_feeds);
    assert!(res == feed1, 0);
  }

  #[test_only]
  public fun init_t(ctx: &mut TxContext) {
    init(X_ORACLE {}, ctx);
  }

  #[test_only]
  public fun update_price<T>(self: &mut XOracle, clock: &Clock, value: u64) {
    let coin_type = get<T>();
    if (!table::contains(&self.prices, coin_type)) {
      table::add(&mut self.prices, coin_type, price_feed::new(0,0));
    };
    let price_feed = table::borrow_mut(&mut self.prices, coin_type);
    price_feed::update_price_feed(price_feed, value, clock::timestamp_ms(clock) / 1000);
  }
}
