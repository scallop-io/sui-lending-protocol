// mock module of the oracle price feed
module oracle::price_feed {
  use std::fixed_point32::{Self, FixedPoint32};
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use sui::math;
  use x::wit_table::{Self, WitTable};
  use math::fixed_point32_empower;
  use oracle::switchboard_adaptor;


  const ECoinTypeDidntMatch: u64 = 0x10000;

  struct PriceFeedCap has key {
    id: UID,
  }

  struct WitPriceFeeds has drop {}

  struct PriceFeedHolder has key {
    id: UID,
    table: WitTable<WitPriceFeeds, TypeName, PriceFeed>,
  }

  struct PriceFeed has store {
    price: FixedPoint32,
  }

  fun init(ctx: &mut TxContext) {
    transfer::transfer(PriceFeedCap {
      id: object::new(ctx),
    }, tx_context::sender(ctx));

    transfer::share_object(PriceFeedHolder {
      id: object::new(ctx),
      table: wit_table::new(WitPriceFeeds {}, true, ctx),
    });
  }

  public fun price(price_feed: &PriceFeed): FixedPoint32 { price_feed.price }

  public fun price_feed(price_feeds: &PriceFeedHolder, coin_type: TypeName): &PriceFeed {
    wit_table::borrow(
      &price_feeds.table,
      coin_type
    )
  }

  public fun calculate_coin_in_usd(price_feed: &PriceFeed, coin_amount: u64, decimals: u8): FixedPoint32 {
    let unscaled_coin_amount = fixed_point32::create_from_rational(coin_amount, math::pow(10, decimals));
    fixed_point32_empower::mul(price_feed.price, unscaled_coin_amount)
  }

  public entry fun add_price_feed<T>(_: &PriceFeedCap, price_feeds: &mut PriceFeedHolder, price: u64, scale: u64) {
    let coin_type = type_name::get<T>();
    wit_table::add(WitPriceFeeds {}, &mut price_feeds.table, coin_type, PriceFeed {
      price: fixed_point32::create_from_rational(price, scale)
    });
  }

  public entry fun update_price<T>(_: &PriceFeedCap, price_feeds: &mut PriceFeedHolder, price: u64, scale: u64) {
    let coin_type = type_name::get<T>();
    let price_feed = wit_table::borrow_mut(WitPriceFeeds {}, &mut price_feeds.table, coin_type);
    price_feed.price = fixed_point32::create_from_rational(price, scale);
  }

  #[test_only]
  public fun init_oracle(ctx: &mut TxContext) {
    init(ctx);
  }
}
