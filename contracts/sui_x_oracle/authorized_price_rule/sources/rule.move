module authorized_price_rule::rule;

use sui::clock::Clock;

use x_oracle::x_oracle::{Self, XOraclePriceUpdateRequest};
use x_oracle::price_feed::{Self, PriceFeed};

use authorized_price_rule::authorized_price_registry::{Self, AuthorizedPriceRegistry};

public struct Rule has drop {}

public fun set_price_as_primary<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    registry: &AuthorizedPriceRegistry,
    price: u64, // USD price with 9 decimals (price_feed::decimals())
    clock: &Clock,
    ctx: &TxContext,
) {
    let price_feed = build_price_feed<CoinType>(registry, price, clock, ctx);
    x_oracle::set_primary_price(Rule {}, request, price_feed);
}

public fun set_price_as_secondary<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    registry: &AuthorizedPriceRegistry,
    price: u64, // USD price with 9 decimals (price_feed::decimals())
    clock: &Clock,
    ctx: &TxContext,
) {
    let price_feed = build_price_feed<CoinType>(registry, price, clock, ctx);
    x_oracle::set_secondary_price(Rule {}, request, price_feed);
}

fun build_price_feed<CoinType>(
    registry: &AuthorizedPriceRegistry,
    price: u64,
    clock: &Clock,
    ctx: &TxContext,
): PriceFeed {
    authorized_price_registry::assert_authorized(registry, ctx.sender());
    authorized_price_registry::assert_price_in_range<CoinType>(registry, price);

    price_feed::new(price, clock.timestamp_ms() / 1000)
}
