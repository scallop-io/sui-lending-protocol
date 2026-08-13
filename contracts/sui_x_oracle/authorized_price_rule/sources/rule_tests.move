#[test_only]
module authorized_price_rule::rule_tests;

use std::type_name;
use std::unit_test::{assert_eq, destroy};
use sui::clock::{Self, Clock};
use sui::table;
use sui::test_scenario::{Self, Scenario};

use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};
use x_oracle::price_feed;

use authorized_price_rule::rule::{Self, Rule};
use authorized_price_rule::authorized_price_registry::{
    Self,
    AuthorizedPriceRegistry,
    AuthorizedPriceRegistryCap
};

const ADMIN: address = @0xAD;
const FEEDER: address = @0xFE;
const KEEPER: address = @0xCE;

public struct TEST_COIN has drop {}

fun setup(
    scenario: &mut Scenario,
): (Clock, XOracle, XOraclePolicyCap, AuthorizedPriceRegistry, AuthorizedPriceRegistryCap) {
    x_oracle::init_t(scenario.ctx());
    authorized_price_registry::init_t(scenario.ctx());
    scenario.next_tx(ADMIN);

    let mut clock = clock::create_for_testing(scenario.ctx());
    clock.set_for_testing(1000 * 1000);

    let mut x_oracle = scenario.take_shared<XOracle>();
    let policy_cap = scenario.take_from_sender<XOraclePolicyCap>();
    let registry = scenario.take_shared<AuthorizedPriceRegistry>();
    let registry_cap = scenario.take_from_sender<AuthorizedPriceRegistryCap>();
    x_oracle::init_rules_df_if_not_exist(&policy_cap, &mut x_oracle, scenario.ctx());

    (clock, x_oracle, policy_cap, registry, registry_cap)
}

fun cleanup(
    clock: Clock,
    x_oracle: XOracle,
    policy_cap: XOraclePolicyCap,
    registry: AuthorizedPriceRegistry,
    registry_cap: AuthorizedPriceRegistryCap,
) {
    destroy(clock);
    destroy(x_oracle);
    destroy(policy_cap);
    destroy(registry);
    destroy(registry_cap);
}

#[test]
fun stored_price_is_relayed_to_x_oracle() {
    let mut scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, mut x_oracle, policy_cap, mut registry, registry_cap) = setup(scenario);

    x_oracle::add_primary_price_update_rule_v2<TEST_COIN, Rule>(&mut x_oracle, &policy_cap);
    authorized_price_registry::add_authorized_address(&mut registry, &registry_cap, FEEDER);
    // $1 ~ $3
    authorized_price_registry::set_price_range<TEST_COIN>(
        &mut registry,
        &registry_cap,
        1,
        3,
        0,
    );

    // The authorized address stores the price in the registry
    scenario.next_tx(FEEDER);
    authorized_price_registry::set_price<TEST_COIN>(
        &mut registry,
        2_000_000_000,
        &clock,
        scenario.ctx(),
    );

    // Anyone can then pull the stored price into x_oracle
    scenario.next_tx(KEEPER);
    let mut request = x_oracle::price_update_request<TEST_COIN>(&x_oracle);
    rule::set_price_as_primary<TEST_COIN>(&mut request, &registry, &clock);
    x_oracle::confirm_price_update_request<TEST_COIN>(&mut x_oracle, request, &clock);

    let prices = x_oracle::prices(&x_oracle);
    let feed = table::borrow(prices, type_name::with_defining_ids<TEST_COIN>());
    assert_eq!(price_feed::value(feed), 2_000_000_000);

    cleanup(clock, x_oracle, policy_cap, registry, registry_cap);
    scenario_value.end();
}

#[test]
fun primary_and_secondary_prices_confirm_together() {
    let mut scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, mut x_oracle, policy_cap, mut registry, registry_cap) = setup(scenario);

    x_oracle::add_primary_price_update_rule_v2<TEST_COIN, Rule>(&mut x_oracle, &policy_cap);
    x_oracle::add_secondary_price_update_rule_v2<TEST_COIN, Rule>(&mut x_oracle, &policy_cap);
    authorized_price_registry::add_authorized_address(&mut registry, &registry_cap, FEEDER);
    // $1 ~ $3
    authorized_price_registry::set_price_range<TEST_COIN>(
        &mut registry,
        &registry_cap,
        1,
        3,
        0,
    );

    scenario.next_tx(FEEDER);
    authorized_price_registry::set_price<TEST_COIN>(
        &mut registry,
        2_000_000_000,
        &clock,
        scenario.ctx(),
    );

    scenario.next_tx(KEEPER);
    let mut request = x_oracle::price_update_request<TEST_COIN>(&x_oracle);
    rule::set_price_as_primary<TEST_COIN>(&mut request, &registry, &clock);
    rule::set_price_as_secondary<TEST_COIN>(&mut request, &registry, &clock);
    x_oracle::confirm_price_update_request<TEST_COIN>(&mut x_oracle, request, &clock);

    let prices = x_oracle::prices(&x_oracle);
    let feed = table::borrow(prices, type_name::with_defining_ids<TEST_COIN>());
    assert_eq!(price_feed::value(feed), 2_000_000_000);

    cleanup(clock, x_oracle, policy_cap, registry, registry_cap);
    scenario_value.end();
}

#[test, expected_failure(
    abort_code = authorized_price_registry::ERR_UNAUTHORIZED_ADDRESS,
    location = authorized_price_rule::authorized_price_registry,
)]
fun unauthorized_sender_cannot_store_price() {
    let mut scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, x_oracle, policy_cap, mut registry, registry_cap) = setup(scenario);

    // $1 ~ $3
    authorized_price_registry::set_price_range<TEST_COIN>(
        &mut registry,
        &registry_cap,
        1,
        3,
        0,
    );

    // FEEDER was never authorized
    scenario.next_tx(FEEDER);
    authorized_price_registry::set_price<TEST_COIN>(
        &mut registry,
        2_000_000_000,
        &clock,
        scenario.ctx(),
    );

    cleanup(clock, x_oracle, policy_cap, registry, registry_cap);
    scenario_value.end();
}

#[test, expected_failure(
    abort_code = authorized_price_registry::ERR_PRICE_STALE,
    location = authorized_price_rule::authorized_price_registry,
)]
fun stale_price_cannot_be_relayed() {
    let mut scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (mut clock, mut x_oracle, policy_cap, mut registry, registry_cap) = setup(scenario);

    x_oracle::add_primary_price_update_rule_v2<TEST_COIN, Rule>(&mut x_oracle, &policy_cap);
    authorized_price_registry::add_authorized_address(&mut registry, &registry_cap, FEEDER);
    // $1 ~ $3
    authorized_price_registry::set_price_range<TEST_COIN>(
        &mut registry,
        &registry_cap,
        1,
        3,
        0,
    );

    scenario.next_tx(FEEDER);
    authorized_price_registry::set_price<TEST_COIN>(
        &mut registry,
        2_000_000_000,
        &clock,
        scenario.ctx(),
    );

    // Advance past the price valid duration, so the stored price becomes stale
    let valid_duration = authorized_price_registry::price_valid_duration(&registry);
    clock.set_for_testing((1000 + valid_duration + 1) * 1000);

    scenario.next_tx(KEEPER);
    let mut request = x_oracle::price_update_request<TEST_COIN>(&x_oracle);
    rule::set_price_as_primary<TEST_COIN>(&mut request, &registry, &clock);

    destroy(request);
    cleanup(clock, x_oracle, policy_cap, registry, registry_cap);
    scenario_value.end();
}

#[test, expected_failure(
    abort_code = authorized_price_registry::ERR_PRICE_NOT_FOUND,
    location = authorized_price_rule::authorized_price_registry,
)]
fun relay_without_stored_price_aborts() {
    let mut scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, mut x_oracle, policy_cap, mut registry, registry_cap) = setup(scenario);

    x_oracle::add_primary_price_update_rule_v2<TEST_COIN, Rule>(&mut x_oracle, &policy_cap);
    authorized_price_registry::add_authorized_address(&mut registry, &registry_cap, FEEDER);
    // $1 ~ $3
    authorized_price_registry::set_price_range<TEST_COIN>(
        &mut registry,
        &registry_cap,
        1,
        3,
        0,
    );

    scenario.next_tx(KEEPER);
    let mut request = x_oracle::price_update_request<TEST_COIN>(&x_oracle);
    rule::set_price_as_primary<TEST_COIN>(&mut request, &registry, &clock);

    destroy(request);
    cleanup(clock, x_oracle, policy_cap, registry, registry_cap);
    scenario_value.end();
}
