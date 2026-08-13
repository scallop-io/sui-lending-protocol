module authorized_price_rule::authorized_price_registry;

use std::type_name::{Self, TypeName};
use sui::clock::Clock;
use sui::event;
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};

use decimal::decimal::{Self, Decimal};
use x_oracle::price_feed;

const ERR_ILLEGAL_REGISTRY_CAP: u64 = 0x11501;
const ERR_UNAUTHORIZED_ADDRESS: u64 = 0x11502;
const ERR_ADDRESS_ALREADY_AUTHORIZED: u64 = 0x11503;
const ERR_ADDRESS_NOT_AUTHORIZED: u64 = 0x11504;
const ERR_INVALID_PRICE_RANGE: u64 = 0x11505;
const ERR_PRICE_RANGE_NOT_FOUND: u64 = 0x11506;
const ERR_PRICE_OUT_OF_RANGE: u64 = 0x11507;
const ERR_INVALID_PRICE_DECIMALS: u64 = 0x11508;
const ERR_PRICE_NOT_FOUND: u64 = 0x11509;
const ERR_PRICE_STALE: u64 = 0x1150A;
const ERR_INVALID_PRICE_VALID_DURATION: u64 = 0x1150B;

// 10^19 overflows u64, so price range inputs can carry at most 18 decimals
const MAX_PRICE_DECIMALS: u8 = 18;
// Same staleness tolerance as pyth_rule; admin can change it with `set_price_valid_duration`
const DEFAULT_PRICE_VALID_DURATION: u64 = 60; // seconds

public struct PriceRange has store, drop {
    min_price: Decimal, // USD price
    max_price: Decimal,
}

public struct PriceData has store, drop {
    price: u64, // USD price with 9 decimals (price_feed::decimals())
    last_updated: u64, // seconds
}

public struct AuthorizedPriceRegistry has key {
    id: UID,
    authorized_addresses: VecSet<address>,
    price_ranges: Table<TypeName, PriceRange>,
    prices: Table<TypeName, PriceData>,
    price_valid_duration: u64, // seconds
}

public struct AuthorizedPriceRegistryCap has key, store {
    id: UID,
    parent: ID,
}

public struct AddAuthorizedAddressEvent has copy, drop {
    addr: address,
}

public struct RemoveAuthorizedAddressEvent has copy, drop {
    addr: address,
}

public struct SetPriceRangeEvent has copy, drop {
    coin_type: TypeName,
    min_price: u64,
    max_price: u64,
    decimals: u8,
}

public struct RemovePriceRangeEvent has copy, drop {
    coin_type: TypeName,
}

public struct SetPriceEvent has copy, drop {
    coin_type: TypeName,
    price: u64,
    last_updated: u64,
    set_by: address,
}

public struct SetPriceValidDurationEvent has copy, drop {
    price_valid_duration: u64,
}

fun init(ctx: &mut TxContext) {
    let (registry, cap) = new(ctx);
    transfer::share_object(registry);
    transfer::transfer(cap, ctx.sender());
}

fun new(ctx: &mut TxContext): (AuthorizedPriceRegistry, AuthorizedPriceRegistryCap) {
    let registry = AuthorizedPriceRegistry {
        id: object::new(ctx),
        authorized_addresses: vec_set::empty(),
        price_ranges: table::new(ctx),
        prices: table::new(ctx),
        price_valid_duration: DEFAULT_PRICE_VALID_DURATION,
    };
    let cap = AuthorizedPriceRegistryCap {
        id: object::new(ctx),
        parent: object::id(&registry),
    };
    (registry, cap)
}

public fun add_authorized_address(
    registry: &mut AuthorizedPriceRegistry,
    cap: &AuthorizedPriceRegistryCap,
    addr: address,
) {
    assert_cap(registry, cap);
    assert!(!registry.authorized_addresses.contains(&addr), ERR_ADDRESS_ALREADY_AUTHORIZED);
    registry.authorized_addresses.insert(addr);

    event::emit(AddAuthorizedAddressEvent { addr });
}

public fun remove_authorized_address(
    registry: &mut AuthorizedPriceRegistry,
    cap: &AuthorizedPriceRegistryCap,
    addr: address,
) {
    assert_cap(registry, cap);
    assert!(registry.authorized_addresses.contains(&addr), ERR_ADDRESS_NOT_AUTHORIZED);
    registry.authorized_addresses.remove(&addr);

    event::emit(RemoveAuthorizedAddressEvent { addr });
}

// @dev The range bounds are USD prices expressed as `value / 10^decimals`,
// e.g. (min_price = 150, decimals = 2) means $1.50
public fun set_price_range<CoinType>(
    registry: &mut AuthorizedPriceRegistry,
    cap: &AuthorizedPriceRegistryCap,
    min_price: u64,
    max_price: u64,
    decimals: u8,
) {
    assert_cap(registry, cap);
    assert!(decimals <= MAX_PRICE_DECIMALS, ERR_INVALID_PRICE_DECIMALS);
    assert!(min_price > 0, ERR_INVALID_PRICE_RANGE);
    assert!(min_price <= max_price, ERR_INVALID_PRICE_RANGE);

    let denominator = decimal::from(std::u64::pow(10, decimals));
    let min_price_usd = decimal::from(min_price).div(denominator);
    let max_price_usd = decimal::from(max_price).div(denominator);

    let coin_type = type_name::with_defining_ids<CoinType>();
    if (registry.price_ranges.contains(coin_type)) {
        let price_range = registry.price_ranges.borrow_mut(coin_type);
        price_range.min_price = min_price_usd;
        price_range.max_price = max_price_usd;
    } else {
        registry.price_ranges.add(
            coin_type,
            PriceRange { min_price: min_price_usd, max_price: max_price_usd },
        );
    };

    event::emit(SetPriceRangeEvent { coin_type, min_price, max_price, decimals });
}

public fun remove_price_range<CoinType>(
    registry: &mut AuthorizedPriceRegistry,
    cap: &AuthorizedPriceRegistryCap,
) {
    assert_cap(registry, cap);

    let coin_type = type_name::with_defining_ids<CoinType>();
    assert!(registry.price_ranges.contains(coin_type), ERR_PRICE_RANGE_NOT_FOUND);
    registry.price_ranges.remove(coin_type);

    event::emit(RemovePriceRangeEvent { coin_type });
}

public fun set_price_valid_duration(
    registry: &mut AuthorizedPriceRegistry,
    cap: &AuthorizedPriceRegistryCap,
    price_valid_duration: u64, // seconds
) {
    assert_cap(registry, cap);
    assert!(price_valid_duration > 0, ERR_INVALID_PRICE_VALID_DURATION);
    registry.price_valid_duration = price_valid_duration;

    event::emit(SetPriceValidDurationEvent { price_valid_duration });
}

// @dev Only authorized addresses can store a price, and it must be within the safe range
// `price` is a USD price with 9 decimals (price_feed::decimals())
public fun set_price<CoinType>(
    registry: &mut AuthorizedPriceRegistry,
    price: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert_authorized(registry, ctx.sender());
    assert_price_in_range<CoinType>(registry, price);

    let last_updated = clock.timestamp_ms() / 1000;
    let coin_type = type_name::with_defining_ids<CoinType>();
    if (registry.prices.contains(coin_type)) {
        let price_data = registry.prices.borrow_mut(coin_type);
        price_data.price = price;
        price_data.last_updated = last_updated;
    } else {
        registry.prices.add(coin_type, PriceData { price, last_updated });
    };

    event::emit(SetPriceEvent { coin_type, price, last_updated, set_by: ctx.sender() });
}

// Returns (price, last_updated) of the stored price.
// Aborts if the price is stale, or no longer within the safe range
public fun get_price<CoinType>(registry: &AuthorizedPriceRegistry, clock: &Clock): (u64, u64) {
    let coin_type = type_name::with_defining_ids<CoinType>();
    assert!(registry.prices.contains(coin_type), ERR_PRICE_NOT_FOUND);
    let price_data = registry.prices.borrow(coin_type);

    let now = clock.timestamp_ms() / 1000;
    assert!(now <= price_data.last_updated + registry.price_valid_duration, ERR_PRICE_STALE);

    // Re-check the range, in case it was tightened after the price was stored
    assert_price_in_range<CoinType>(registry, price_data.price);

    (price_data.price, price_data.last_updated)
}

public fun is_authorized(registry: &AuthorizedPriceRegistry, addr: address): bool {
    registry.authorized_addresses.contains(&addr)
}

public fun assert_authorized(registry: &AuthorizedPriceRegistry, addr: address) {
    assert!(is_authorized(registry, addr), ERR_UNAUTHORIZED_ADDRESS);
}

public fun price_range<CoinType>(registry: &AuthorizedPriceRegistry): (Decimal, Decimal) {
    let coin_type = type_name::with_defining_ids<CoinType>();
    assert!(registry.price_ranges.contains(coin_type), ERR_PRICE_RANGE_NOT_FOUND);
    let price_range = registry.price_ranges.borrow(coin_type);
    (price_range.min_price, price_range.max_price)
}

// @dev `price` is a USD price with 9 decimals (price_feed::decimals())
public fun assert_price_in_range<CoinType>(registry: &AuthorizedPriceRegistry, price: u64) {
    let (min_price, max_price) = price_range<CoinType>(registry);
    let price_usd = decimal::from(price).div(
        decimal::from(std::u64::pow(10, price_feed::decimals())),
    );
    assert!(price_usd.ge(min_price) && price_usd.le(max_price), ERR_PRICE_OUT_OF_RANGE);
}

public fun price_valid_duration(registry: &AuthorizedPriceRegistry): u64 {
    registry.price_valid_duration
}

fun assert_cap(registry: &AuthorizedPriceRegistry, cap: &AuthorizedPriceRegistryCap) {
    assert!(object::id(registry) == cap.parent, ERR_ILLEGAL_REGISTRY_CAP);
}

// === Test helpers ===

#[test_only]
public fun init_t(ctx: &mut TxContext) {
    init(ctx);
}

#[test_only]
public fun new_for_testing(
    ctx: &mut TxContext,
): (AuthorizedPriceRegistry, AuthorizedPriceRegistryCap) {
    new(ctx)
}

// === Tests ===

#[test_only]
use std::unit_test::{assert_eq, destroy};
#[test_only]
use sui::clock;

#[test_only]
public struct TEST_COIN has drop {}

#[test]
fun add_and_remove_authorized_address_updates_allowlist() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    assert!(!is_authorized(&registry, @0xFE));
    add_authorized_address(&mut registry, &cap, @0xFE);
    assert!(is_authorized(&registry, @0xFE));
    remove_authorized_address(&mut registry, &cap, @0xFE);
    assert!(!is_authorized(&registry, @0xFE));

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_ADDRESS_ALREADY_AUTHORIZED)]
fun add_duplicate_authorized_address_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    add_authorized_address(&mut registry, &cap, @0xFE);
    add_authorized_address(&mut registry, &cap, @0xFE);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_ADDRESS_NOT_AUTHORIZED)]
fun remove_unknown_authorized_address_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    remove_authorized_address(&mut registry, &cap, @0xFE);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_ILLEGAL_REGISTRY_CAP)]
fun admin_call_with_mismatched_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry_a, cap_a) = new_for_testing(ctx);
    let (registry_b, cap_b) = new_for_testing(ctx);

    add_authorized_address(&mut registry_a, &cap_b, @0xFE);

    destroy(registry_a);
    destroy(cap_a);
    destroy(registry_b);
    destroy(cap_b);
}

#[test]
fun set_price_range_reads_back_and_overwrites() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    let (min_price, max_price) = price_range<TEST_COIN>(&registry);
    assert_eq!(min_price, decimal::from(1));
    assert_eq!(max_price, decimal::from(3));

    // (200, 450, decimals = 2) means $2.00 ~ $4.50
    set_price_range<TEST_COIN>(&mut registry, &cap, 200, 450, 2);
    let (min_price, max_price) = price_range<TEST_COIN>(&registry);
    assert_eq!(min_price, decimal::from(2));
    assert_eq!(max_price, decimal::from_percent_u64(450));

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_INVALID_PRICE_RANGE)]
fun set_price_range_with_min_greater_than_max_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 2, 1, 0);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_INVALID_PRICE_RANGE)]
fun set_price_range_with_zero_min_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 0, 1, 0);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_INVALID_PRICE_DECIMALS)]
fun set_price_range_with_too_many_decimals_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 19);

    destroy(registry);
    destroy(cap);
}

#[test]
fun price_at_range_bounds_is_accepted() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    assert_price_in_range<TEST_COIN>(&registry, 1_000_000_000);
    assert_price_in_range<TEST_COIN>(&registry, 3_000_000_000);

    destroy(registry);
    destroy(cap);
}

#[test]
fun fractional_range_bounds_are_enforced_exactly() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    // (55, 125, decimals = 2) means $0.55 ~ $1.25
    set_price_range<TEST_COIN>(&mut registry, &cap, 55, 125, 2);
    assert_price_in_range<TEST_COIN>(&registry, 550_000_000);
    assert_price_in_range<TEST_COIN>(&registry, 1_250_000_000);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_PRICE_OUT_OF_RANGE)]
fun price_below_fractional_min_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    // (55, 125, decimals = 2) means $0.55 ~ $1.25
    set_price_range<TEST_COIN>(&mut registry, &cap, 55, 125, 2);
    assert_price_in_range<TEST_COIN>(&registry, 549_999_999);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_PRICE_OUT_OF_RANGE)]
fun price_below_min_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    assert_price_in_range<TEST_COIN>(&registry, 999_999_999);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_PRICE_OUT_OF_RANGE)]
fun price_above_max_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    assert_price_in_range<TEST_COIN>(&registry, 3_000_000_001);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_PRICE_RANGE_NOT_FOUND)]
fun price_check_without_registered_range_aborts() {
    let ctx = &mut tx_context::dummy();
    let (registry, cap) = new_for_testing(ctx);

    assert_price_in_range<TEST_COIN>(&registry, 1_000_000_000);

    destroy(registry);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERR_PRICE_RANGE_NOT_FOUND)]
fun price_check_after_range_removed_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    remove_price_range<TEST_COIN>(&mut registry, &cap);
    assert_price_in_range<TEST_COIN>(&registry, 1_000_000_000);

    destroy(registry);
    destroy(cap);
}

#[test]
fun set_price_stores_and_get_price_returns_it() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000 * 1000);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    let (price, last_updated) = get_price<TEST_COIN>(&registry, &clock);
    assert_eq!(price, 2_000_000_000);
    assert_eq!(last_updated, 1000);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test]
fun set_price_overwrites_previous_price() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000 * 1000);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    clock.set_for_testing(1010 * 1000);
    set_price<TEST_COIN>(&mut registry, 2_500_000_000, &clock, ctx);

    let (price, last_updated) = get_price<TEST_COIN>(&registry, &clock);
    assert_eq!(price, 2_500_000_000);
    assert_eq!(last_updated, 1010);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_UNAUTHORIZED_ADDRESS)]
fun set_price_by_unauthorized_sender_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let clock = clock::create_for_testing(ctx);

    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_PRICE_OUT_OF_RANGE)]
fun set_price_out_of_range_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let clock = clock::create_for_testing(ctx);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 4_000_000_000, &clock, ctx);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_PRICE_RANGE_NOT_FOUND)]
fun set_price_without_registered_range_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let clock = clock::create_for_testing(ctx);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_PRICE_NOT_FOUND)]
fun get_price_without_stored_price_aborts() {
    let ctx = &mut tx_context::dummy();
    let (registry, cap) = new_for_testing(ctx);
    let clock = clock::create_for_testing(ctx);

    get_price<TEST_COIN>(&registry, &clock);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test]
fun price_at_staleness_boundary_is_accepted() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000 * 1000);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    clock.set_for_testing((1000 + DEFAULT_PRICE_VALID_DURATION) * 1000);
    let (price, _) = get_price<TEST_COIN>(&registry, &clock);
    assert_eq!(price, 2_000_000_000);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_PRICE_STALE)]
fun stale_price_cannot_be_pulled() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000 * 1000);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    clock.set_for_testing((1000 + DEFAULT_PRICE_VALID_DURATION + 1) * 1000);
    get_price<TEST_COIN>(&registry, &clock);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_PRICE_OUT_OF_RANGE)]
fun stored_price_outside_updated_range_cannot_be_pulled() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let clock = clock::create_for_testing(ctx);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    // Tighten the range to $0.1 ~ $1.5, so the stored $2 is no longer valid
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 15, 1);
    get_price<TEST_COIN>(&registry, &clock);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test]
fun set_price_valid_duration_updates_staleness_window() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);
    let mut clock = clock::create_for_testing(ctx);
    clock.set_for_testing(1000 * 1000);

    assert_eq!(price_valid_duration(&registry), DEFAULT_PRICE_VALID_DURATION);
    set_price_valid_duration(&mut registry, &cap, 100);
    assert_eq!(price_valid_duration(&registry), 100);

    add_authorized_address(&mut registry, &cap, ctx.sender());
    set_price_range<TEST_COIN>(&mut registry, &cap, 1, 3, 0);
    set_price<TEST_COIN>(&mut registry, 2_000_000_000, &clock, ctx);

    // Would be stale under the default 30s window, but valid under the new 100s window
    clock.set_for_testing(1100 * 1000);
    let (price, _) = get_price<TEST_COIN>(&registry, &clock);
    assert_eq!(price, 2_000_000_000);

    destroy(registry);
    destroy(cap);
    destroy(clock);
}

#[test, expected_failure(abort_code = ERR_INVALID_PRICE_VALID_DURATION)]
fun set_zero_price_valid_duration_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut registry, cap) = new_for_testing(ctx);

    set_price_valid_duration(&mut registry, &cap, 0);

    destroy(registry);
    destroy(cap);
}
