#[test_only]
module protocol::balance_migration_test {

  use std::type_name;
  use sui::test_scenario::{Self, Scenario};
  use sui::test_utils;
  use sui::coin;
  use sui::balance;
  use sui::bag;
  use sui::clock::{Self, Clock};
  use x::balance_bag;
  use x::wit_table;
  use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::balance_migration;
  use protocol::borrow;
  use protocol::repay;
  use protocol::deposit_collateral;
  use protocol::withdraw_collateral;
  use protocol::mint;
  use protocol::reserve;
  use protocol::version::{Self, Version};
  use protocol::app::{Self, AdminCap};
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::market::{Self, Market};
  use protocol::constants::{usdc_interest_model_params, eth_risk_model_params, eth_interest_model_params};
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use protocol::oracle_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;

  const ADMIN: address = @0xAD;
  const LENDER: address = @0xAA;
  const BORROWER: address = @0xBB;
  const MIGRATOR: address = @0xCC;

  const USDC_DECIMALS: u8 = 9;
  const ETH_DECIMALS: u8 = 9;

  // USDC = $1, ETH = $1000. Lender supplies 10_000 USDC, borrower deposits 1 ETH and
  // borrows 500 USDC. MIGRATOR is in the balance migration authority registry.
  fun setup(
    scenario: &mut Scenario,
  ): (Clock, Version, Market, AdminCap, XOracle, XOraclePolicyCap, CoinDecimalsRegistry, Obligation, ObligationKey) {
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);
    let usdc_interest_params = usdc_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);
    test_scenario::next_tx(scenario, ADMIN);

    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let eth_interest_params = eth_interest_model_params();
    add_interest_model_t<ETH>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &eth_interest_params, &clock);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, USDC_DECIMALS);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, ETH_DECIMALS);

    test_scenario::next_tx(scenario, ADMIN);
    app::add_balance_migration_authority(&admin_cap, &mut market, MIGRATOR, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, LENDER);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(10_000 * std::u64::pow(10, USDC_DECIMALS), test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, BORROWER);
    let eth_coin = coin::mint_for_testing<ETH>(std::u64::pow(10, ETH_DECIMALS), test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0));
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0));
    protocol::apm::refresh_apm_state<USDC>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));
    protocol::apm::refresh_apm_state<ETH>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, BORROWER);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 500 * std::u64::pow(10, USDC_DECIMALS), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(borrowed);

    (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key)
  }

  fun teardown(
    scenario_value: Scenario,
    clock: Clock,
    version: Version,
    market: Market,
    admin_cap: AdminCap,
    x_oracle: XOracle,
    x_oracle_policy_cap: XOraclePolicyCap,
    coin_decimals_registry: CoinDecimalsRegistry,
    obligation: Obligation,
    obligation_key: ObligationKey,
  ) {
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(ADMIN, admin_cap);
    test_scenario::return_to_address(ADMIN, x_oracle_policy_cap);
    test_scenario::return_to_address(BORROWER, obligation_key);
    test_scenario::end(scenario_value);
  }

  // Recreate a market and obligation from before the dynamic-field storage existed.
  fun move_all_to_legacy_storage(market: &mut Market, obligation: &mut Obligation) {
    let vault = market::vault_mut_for_testing(market);
    reserve::move_to_legacy_storage_for_testing<USDC>(vault);
    reserve::move_to_legacy_storage_for_testing<ETH>(vault);
    obligation::move_to_legacy_storage_for_testing<ETH>(obligation);
  }

  fun cash<T>(market: &Market): u64 {
    let balance_sheets = reserve::balance_sheets(market::vault(market));
    let (cash, _, _, _) = reserve::balance_sheet(wit_table::borrow(balance_sheets, type_name::get<T>()));
    cash
  }

  fun reserve_balance<T>(market: &Market): u64 {
    balance_bag::value<T>(reserve::underlying_balances(market::vault(market)))
  }

  fun collateral_balance<T>(obligation: &Obligation): u64 {
    balance_bag::value<T>(obligation::balance_bag(obligation))
  }

  fun legacy_reserve_storage_is_empty(market: &Market): bool {
    bag::is_empty(balance_bag::bag(reserve::legacy_underlying_balances_for_testing(market::vault(market))))
  }

  fun legacy_obligation_storage_is_empty(obligation: &Obligation): bool {
    bag::is_empty(balance_bag::bag(obligation::legacy_balances_for_testing(obligation)))
  }

  #[test]
  fun new_market_and_obligation_use_dynamic_field_storage_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);

    assert!(reserve::is_underlying_balances_migrated_for_testing(market::vault(&market)), 0);
    assert!(legacy_reserve_storage_is_empty(&market), 1);
    assert!(reserve_balance<USDC>(&market) == 9_500 * std::u64::pow(10, USDC_DECIMALS), 2);
    assert!(reserve_balance<USDC>(&market) == cash<USDC>(&market), 3);

    assert!(obligation::is_collateral_balances_migrated_for_testing(&obligation), 4);
    assert!(legacy_obligation_storage_is_empty(&obligation), 5);
    assert!(collateral_balance<ETH>(&obligation) == std::u64::pow(10, ETH_DECIMALS), 6);

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test]
  fun legacy_storage_works_until_migrated_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);
    move_all_to_legacy_storage(&mut market, &mut obligation);
    assert!(!reserve::is_underlying_balances_migrated_for_testing(market::vault(&market)), 0);
    assert!(!obligation::is_collateral_balances_migrated_for_testing(&obligation), 1);

    // User flows keep working on the legacy layout.
    test_scenario::next_tx(scenario, BORROWER);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, USDC_DECIMALS), test_scenario::ctx(scenario));
    repay::repay<USDC>(&version, &mut obligation, &mut market, repay_coin, &clock, test_scenario::ctx(scenario));
    let eth_coin = coin::mint_for_testing<ETH>(std::u64::pow(10, ETH_DECIMALS), test_scenario::ctx(scenario));
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
    let withdrawn = withdraw_collateral::withdraw_collateral<ETH>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 5 * std::u64::pow(10, ETH_DECIMALS - 1), &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&withdrawn) == 5 * std::u64::pow(10, ETH_DECIMALS - 1), 2);
    coin::burn_for_testing(withdrawn);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 50 * std::u64::pow(10, USDC_DECIMALS), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(borrowed);

    assert!(!reserve::is_underlying_balances_migrated_for_testing(market::vault(&market)), 3);
    assert!(!obligation::is_collateral_balances_migrated_for_testing(&obligation), 4);
    let cash_before = cash<USDC>(&market);
    let collateral_before = obligation::collateral(&obligation, type_name::get<ETH>());
    assert!(reserve_balance<USDC>(&market) == cash_before, 5);
    assert!(collateral_balance<ETH>(&obligation) == collateral_before, 6);

    // Migrate the reserve and the obligation.
    test_scenario::next_tx(scenario, ADMIN);
    balance_migration::migrate_underlying_balance<USDC>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));
    balance_migration::migrate_underlying_balance<ETH>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, MIGRATOR);
    balance_migration::migrate_collateral_balance<ETH>(&version, &market, &mut obligation, test_scenario::ctx(scenario));

    // Balances moved, accounting unchanged, legacy storage empty.
    assert!(reserve::is_underlying_balances_migrated_for_testing(market::vault(&market)), 7);
    assert!(legacy_reserve_storage_is_empty(&market), 8);
    assert!(cash<USDC>(&market) == cash_before, 9);
    assert!(reserve_balance<USDC>(&market) == cash_before, 10);
    assert!(obligation::is_collateral_balances_migrated_for_testing(&obligation), 11);
    assert!(legacy_obligation_storage_is_empty(&obligation), 12);
    assert!(obligation::collateral(&obligation, type_name::get<ETH>()) == collateral_before, 13);
    assert!(collateral_balance<ETH>(&obligation) == collateral_before, 14);

    // Running the migration again moves nothing.
    test_scenario::next_tx(scenario, ADMIN);
    balance_migration::migrate_underlying_balance<USDC>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, MIGRATOR);
    balance_migration::migrate_collateral_balance<ETH>(&version, &market, &mut obligation, test_scenario::ctx(scenario));
    assert!(reserve_balance<USDC>(&market) == cash_before, 15);
    assert!(collateral_balance<ETH>(&obligation) == collateral_before, 16);

    // User flows keep working on the dynamic-field storage.
    test_scenario::next_tx(scenario, BORROWER);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 10 * std::u64::pow(10, USDC_DECIMALS), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(borrowed);
    let withdrawn = withdraw_collateral::withdraw_collateral<ETH>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, std::u64::pow(10, ETH_DECIMALS - 1), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(withdrawn);
    assert!(reserve_balance<USDC>(&market) == cash<USDC>(&market), 17);
    assert!(collateral_balance<ETH>(&obligation) == obligation::collateral(&obligation, type_name::get<ETH>()), 18);
    assert!(legacy_reserve_storage_is_empty(&market), 19);
    assert!(legacy_obligation_storage_is_empty(&obligation), 20);

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test]
  fun leftover_legacy_balance_moves_on_first_use_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);
    move_all_to_legacy_storage(&mut market, &mut obligation);

    // Migrate only ETH in the reserve, and a coin the obligation doesn't hold.
    test_scenario::next_tx(scenario, ADMIN);
    balance_migration::migrate_underlying_balance<ETH>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, MIGRATOR);
    balance_migration::migrate_collateral_balance<USDC>(&version, &market, &mut obligation, test_scenario::ctx(scenario));

    assert!(reserve::is_underlying_balances_migrated_for_testing(market::vault(&market)), 0);
    assert!(balance_bag::contains<USDC>(reserve::legacy_underlying_balances_for_testing(market::vault(&market))), 1);
    assert!(obligation::is_collateral_balances_migrated_for_testing(&obligation), 2);
    assert!(balance_bag::contains<ETH>(obligation::legacy_balances_for_testing(&obligation)), 3);

    // The first use of each coin moves what is left in legacy storage.
    test_scenario::next_tx(scenario, LENDER);
    let usdc_coin = coin::mint_for_testing<USDC>(1_000 * std::u64::pow(10, USDC_DECIMALS), test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(market_coin);
    test_scenario::next_tx(scenario, BORROWER);
    let withdrawn = withdraw_collateral::withdraw_collateral<ETH>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, std::u64::pow(10, ETH_DECIMALS - 1), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(withdrawn);

    assert!(legacy_reserve_storage_is_empty(&market), 4);
    assert!(reserve_balance<USDC>(&market) == cash<USDC>(&market), 5);
    assert!(legacy_obligation_storage_is_empty(&obligation), 6);
    assert!(collateral_balance<ETH>(&obligation) == obligation::collateral(&obligation, type_name::get<ETH>()), 7);

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
  fun legacy_reserve_storage_is_empty_after_migration_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);
    move_all_to_legacy_storage(&mut market, &mut obligation);

    test_scenario::next_tx(scenario, ADMIN);
    balance_migration::migrate_underlying_balance<USDC>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));

    // The coin's entry is gone from legacy storage, so even a zero split aborts.
    let legacy = reserve::legacy_underlying_balances_mut_for_testing(market::vault_mut_for_testing(&mut market));
    balance::destroy_zero(balance_bag::split<USDC>(legacy, 0));

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 1, location = sui::dynamic_field)]
  fun legacy_obligation_storage_is_empty_after_migration_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);
    move_all_to_legacy_storage(&mut market, &mut obligation);

    test_scenario::next_tx(scenario, MIGRATOR);
    balance_migration::migrate_collateral_balance<ETH>(&version, &market, &mut obligation, test_scenario::ctx(scenario));

    // The coin's entry is gone from legacy storage, so nothing can be added back to it.
    balance_bag::join(obligation::legacy_balances_mut_for_testing(&mut obligation), balance::zero<ETH>());

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0018001, location = protocol::balance_migration)]
  fun migrate_collateral_balance_requires_authority_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);

    test_scenario::next_tx(scenario, BORROWER);
    balance_migration::migrate_collateral_balance<ETH>(&version, &market, &mut obligation, test_scenario::ctx(scenario));

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0018001, location = protocol::balance_migration)]
  fun removed_authority_cannot_migrate_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);

    test_scenario::next_tx(scenario, ADMIN);
    app::remove_balance_migration_authority(&admin_cap, &mut market, MIGRATOR, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, MIGRATOR);
    balance_migration::migrate_collateral_balance<ETH>(&version, &market, &mut obligation, test_scenario::ctx(scenario));

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0000201, location = protocol::version)]
  fun migrate_underlying_balance_requires_current_version_test() {
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario);

    test_scenario::next_tx(scenario, ADMIN);
    let version_cap = version::create_cap_for_testing(test_scenario::ctx(scenario));
    version::upgrade(&mut version, &version_cap);
    balance_migration::migrate_underlying_balance<USDC>(&admin_cap, &version, &mut market, test_scenario::ctx(scenario));

    test_utils::destroy(version_cap);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }
}
