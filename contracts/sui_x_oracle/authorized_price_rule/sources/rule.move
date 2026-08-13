module authorized_price_rule::rule;

use sui::clock::Clock;

use x_oracle::x_oracle::{Self, XOraclePriceUpdateRequest};
use x_oracle::price_feed::{Self, PriceFeed};

use authorized_price_rule::authorized_price_registry::{Self, AuthorizedPriceRegistry};

public struct Rule has drop {}

// Pull the price stored by an authorized address into the x_oracle price update request.
// Aborts if the stored price is stale, or no longer within the safe range
public fun set_price_as_primary<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    registry: &AuthorizedPriceRegistry,
    clock: &Clock,
) {
    let price_feed = build_price_feed<CoinType>(registry, clock);
    x_oracle::set_primary_price(Rule {}, request, price_feed);
}

public fun set_price_as_secondary<CoinType>(
    request: &mut XOraclePriceUpdateRequest<CoinType>,
    registry: &AuthorizedPriceRegistry,
    clock: &Clock,
) {
    let price_feed = build_price_feed<CoinType>(registry, clock);
    x_oracle::set_secondary_price(Rule {}, request, price_feed);
}

fun build_price_feed<CoinType>(
    registry: &AuthorizedPriceRegistry,
    clock: &Clock,
): PriceFeed {
    let (price, last_updated) = authorized_price_registry::get_price<CoinType>(registry, clock);
    price_feed::new(price, last_updated)
}
