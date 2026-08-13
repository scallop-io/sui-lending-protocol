module authorized_price_rule::authorized_price_registry;

use std::type_name::{Self, TypeName};
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

// 10^19 overflows u64, so price range inputs can carry at most 18 decimals
const MAX_PRICE_DECIMALS: u8 = 18;

public struct PriceRange has store, drop {
    min_price: Decimal, // USD price
    max_price: Decimal,
}

public struct AuthorizedPriceRegistry has key {
    id: UID,
    authorized_addresses: VecSet<address>,
    price_ranges: Table<TypeName, PriceRange>,
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
