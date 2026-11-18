#[test_only]
module protocol::forced_deleverage_test {

  use std::type_name::{Self, TypeName};
  use std::fixed_point32;
  use std::vector;
  use sui::test_scenario::{Self, Scenario};
  use sui::test_utils;
  use sui::coin;
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::liquidate;
  use protocol::forced_deleverage;
  use protocol::forced_deleverage_evaluator;
  use protocol::price;
  use protocol::version::{Self, Version};
  use protocol::app::{Self, AdminCap};
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::obligation_access::{Self, ObligationAccessStore};
  use protocol::market::Market;
  use protocol::market_t::calc_growth_interest;
  use protocol::constants::{usdc_interest_model_params, eth_risk_model_params, eth_interest_model_params};
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use protocol::oracle_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use test_coin::usdt::USDT;
  use test_coin::btc::BTC;

  const ADMIN: address = @0xAD;
  const LENDER: address = @0xAA;
  const BORROWER: address = @0xBB;
  const EXECUTOR: address = @0xEE;

  const ETH_DECIMALS: u8 = 9;

  // Amount-invariant sweep. Prices are 9-decimal oracle values:
  // $0.000000001, $0.123456789, $999.999999999, $4e9 (near the FixedPoint32 max).
  const PRICE_GRID: vector<u64> = vector[1, 123_456_789, 999_999_999_999, 4_000_000_000_000_000_000];
  const AMOUNT_GRID: vector<u64> = vector[7, 999_999_937, 1_000_000_000_000_007, 18_446_744_073_709_551_615];
  const U64_MAX: u64 = 18_446_744_073_709_551_615;

  struct MockLockKey has drop {}

  // Standard setup, mirroring liquidation_test:
  //   USDC = $1, ETH = $1000 (updated at clock = 300s)
  //   lender supplies 10_000 USDC, borrower deposits 1 ETH and borrows 500 USDC
  //   → healthy position: weighted debt $500 < liq threshold 1 × $1000 × 80% = $800
  //   EXECUTOR is registered in the forced-deleverage authority registry when
  //   `authorize_executor` is true.
  fun setup(
    scenario: &mut Scenario,
    usdc_decimals: u8,
    authorize_executor: bool,
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
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, ETH_DECIMALS);

    if (authorize_executor) {
      test_scenario::next_tx(scenario, ADMIN);
      app::add_forced_deleverage_authority(&admin_cap, &mut market, EXECUTOR, test_scenario::ctx(scenario));
    };

    // lender supplies USDC liquidity
    test_scenario::next_tx(scenario, LENDER);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(std::u64::pow(10, usdc_decimals + 4), test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(market_coin);

    // borrower deposits 1 ETH collateral
    test_scenario::next_tx(scenario, BORROWER);
    let eth_coin = coin::mint_for_testing<ETH>(std::u64::pow(10, ETH_DECIMALS), test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0));    // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0));  // $1000

    protocol::apm::refresh_apm_state<USDC>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));
    protocol::apm::refresh_apm_state<ETH>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));

    // borrower borrows 500 USDC ($500 < $700 borrow capacity)
    test_scenario::next_tx(scenario, BORROWER);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 500 * std::u64::pow(10, usdc_decimals), &x_oracle, &clock, test_scenario::ctx(scenario));
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

  // ── Happy paths ───────────────────────────────────────────────────────────

  #[test]
  fun forced_deleverage_scenario_a_test() {
    // Deprecated debt side: repay 100 USDC ($100), seize exactly $100 of ETH = 0.1 ETH.
    // The obligation is HEALTHY — the defining difference from liquidation.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_amount = 100 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    // $100 / $1000 = 0.1 ETH, exactly
    assert!(coin::value(&seized_coin) == std::u64::pow(10, ETH_DECIMALS - 1), 0);
    assert!(coin::value(&remain_coin) == 0, 1);
    // 1:1 value invariant (same decimals on both sides): seized × $1000 == repaid × $1
    assert!(coin::value(&seized_coin) * 1000 == repay_amount, 2);

    // obligation state: debt 500 → 400 USDC, collateral 1 → 0.9 ETH
    let (debt_amount, _) = obligation::debt(&obligation, type_name::get<USDC>());
    assert!(debt_amount == 400 * std::u64::pow(10, usdc_decimals), 3);
    assert!(obligation::collateral(&obligation, type_name::get<ETH>()) == 9 * std::u64::pow(10, ETH_DECIMALS - 1), 4);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test]
  fun forced_deleverage_scenario_b_asymmetric_decimals_test() {
    // Deprecated collateral side, with asymmetric decimals (6-dec debt vs 9-dec
    // collateral). Verifies the u256 formula exactly against on-chain prices.
    let usdc_decimals = 6;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_amount = 100 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    // Replicate the evaluator formula from on-chain price raws:
    // seized = repay * raw_d * s_c / (raw_c * s_d)
    let raw_d = fixed_point32::get_raw_value(price::get_price(&x_oracle, type_name::get<USDC>(), &clock));
    let raw_c = fixed_point32::get_raw_value(price::get_price(&x_oracle, type_name::get<ETH>(), &clock));
    let expected_seized =
      (repay_amount as u256) * (raw_d as u256) * (std::u64::pow(10, ETH_DECIMALS) as u256)
        / ((raw_c as u256) * (std::u64::pow(10, usdc_decimals) as u256));
    assert!(coin::value(&seized_coin) == (expected_seized as u64), 0);
    // $100 / $1000 = 0.1 ETH regardless of debt decimals
    assert!(coin::value(&seized_coin) == std::u64::pow(10, ETH_DECIMALS - 1), 1);
    assert!(coin::value(&remain_coin) == 0, 2);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0000601, location = protocol::liquidation_evaluator)]
  fun liquidate_aborts_on_healthy_obligation_test() {
    // Contrast test: the same healthy obligation forced_deleverage handles
    // cannot be liquidated (max_repay_amount returns 0 → unable_to_liquidate).
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = liquidate::liquidate<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Caps and refunds ──────────────────────────────────────────────────────

  #[test]
  fun forced_deleverage_repay_capped_at_debt_test() {
    // Supplying more than the debt: repay caps at the full 500 USDC debt, the
    // debt row is deleted, and the excess 100 USDC is refunded.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let supplied = 600 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(supplied, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    // repaid 500 USDC → seized $500 / $1000 = 0.5 ETH; 100 USDC refunded
    assert!(coin::value(&seized_coin) == 5 * std::u64::pow(10, ETH_DECIMALS - 1), 0);
    assert!(coin::value(&remain_coin) == 100 * std::u64::pow(10, usdc_decimals), 1);
    // full repay deletes the debt row
    assert!(!obligation::has_coin_x_as_debt(&obligation, type_name::get<USDC>()), 2);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test]
  fun forced_deleverage_collateral_shortfall_test() {
    // ETH crashes to $400: debt $500 > collateral $400. Seize all collateral,
    // scale the repay down proportionally — exactly $400 repaid for $400 seized.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    // ETH price drops to $400 (same second, so the feed stays fresh)
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(400, 0));

    test_scenario::next_tx(scenario, EXECUTOR);
    let supplied = 600 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(supplied, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    // needed = 500 USDC / $400 = 1.25 ETH > 1 ETH → seize all, repay 400 USDC
    let eth_amount = std::u64::pow(10, ETH_DECIMALS);
    assert!(coin::value(&seized_coin) == eth_amount, 0);
    let repaid = supplied - coin::value(&remain_coin);
    assert!(repaid == 400 * std::u64::pow(10, usdc_decimals), 1);
    // 1:1 value invariant: 1 ETH × $400 == 400 USDC × $1
    assert!(coin::value(&seized_coin) * 400 == repaid, 2);
    // collateral row deleted; 100 USDC debt remains
    assert!(!obligation::has_coin_x_as_collateral(&obligation, type_name::get<ETH>()), 3);
    let (debt_amount, _) = obligation::debt(&obligation, type_name::get<USDC>());
    assert!(debt_amount == 100 * std::u64::pow(10, usdc_decimals), 4);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Freeze / lock policy ──────────────────────────────────────────────────

  #[test]
  fun forced_deleverage_works_while_frozen_test() {
    // freeze_protocol rejects every whitelist-gated flow; forced deleverage
    // deliberately skips the whitelist and must keep working during wind-down.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, ADMIN);
    app::add_pause_authority_registry(&admin_cap, &mut market, ADMIN, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, ADMIN);
    app::freeze_protocol(&version, &mut market, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_amount = 100 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );
    assert!(coin::value(&seized_coin) == std::u64::pow(10, ETH_DECIMALS - 1), 0);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0000302, location = protocol::forced_deleverage)]
  fun forced_deleverage_aborts_when_liquidate_locked_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, ADMIN);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    app::add_lock_key<MockLockKey>(&admin_cap, &mut obligation_access_store);
    // lock flags: borrow, repay, deposit_collateral, withdraw_collateral, liquidate
    obligation::lock(&mut obligation, &obligation_key, &obligation_access_store, false, false, false, false, true, MockLockKey {});

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    test_scenario::return_shared(obligation_access_store);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test]
  fun forced_deleverage_bypasses_repay_and_withdraw_locks_test() {
    // Incentive-program stakes set repay/withdraw locks; forced deleverage
    // follows the liquidation lock policy and must still work.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, ADMIN);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    app::add_lock_key<MockLockKey>(&admin_cap, &mut obligation_access_store);
    // repay_locked = true, withdraw_collateral_locked = true, liquidate_locked = false
    obligation::lock(&mut obligation, &obligation_key, &obligation_access_store, false, true, false, true, false, MockLockKey {});

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_amount = 100 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );
    assert!(coin::value(&seized_coin) == std::u64::pow(10, ETH_DECIMALS - 1), 0);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    test_scenario::return_shared(obligation_access_store);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Authorization ─────────────────────────────────────────────────────────

  #[test, expected_failure(abort_code = 0x0017001, location = protocol::forced_deleverage)]
  fun forced_deleverage_aborts_when_registry_absent_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, false);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017001, location = protocol::forced_deleverage)]
  fun forced_deleverage_aborts_for_unauthorized_sender_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    // sender is not in the registry (EXECUTOR is)
    test_scenario::next_tx(scenario, @0xDD);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017001, location = protocol::forced_deleverage)]
  fun forced_deleverage_aborts_after_authority_removed_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, ADMIN);
    app::remove_forced_deleverage_authority(&admin_cap, &mut market, EXECUTOR, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Row guards and degenerate amounts ─────────────────────────────────────

  #[test, expected_failure(abort_code = 0x0017002, location = protocol::forced_deleverage_evaluator)]
  fun forced_deleverage_aborts_without_debt_row_test() {
    // The obligation owes USDC, not USDT.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDT>(100 * std::u64::pow(10, 9), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDT, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017003, location = protocol::forced_deleverage_evaluator)]
  fun forced_deleverage_aborts_without_collateral_row_test() {
    // The obligation's collateral is ETH, not BTC.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, BTC>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017002, location = protocol::forced_deleverage_evaluator)]
  fun forced_deleverage_same_coin_needs_both_rows_test() {
    // Same coin on both sides is allowed, but borrow and deposit_collateral keep
    // new obligations from holding one coin as both debt and collateral, so on
    // this obligation (ETH collateral, no ETH debt) the debt row guard rejects it.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<ETH>(std::u64::pow(10, ETH_DECIMALS - 1), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<ETH, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017004, location = protocol::forced_deleverage)]
  fun forced_deleverage_aborts_on_zero_coin_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(0, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0017004, location = protocol::forced_deleverage_evaluator)]
  fun forced_deleverage_aborts_on_dust_repay_test() {
    // 1 base unit of USDC ($0.000000001) converts to 0 ETH units → dust guard.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(1, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Amount math (evaluator only) ──────────────────────────────────────────
  //
  // The evaluator reads the debt and collateral rows, never the balances, so
  // these tests build rows-only obligations with the test-only row helpers and
  // need no market.

  #[test]
  fun forced_deleverage_same_coin_nets_exactly_test() {
    // Only obligations that looped before borrow and deposit_collateral started
    // rejecting same-coin positions can hold one coin on both sides. Prices and
    // scales cancel, so every path returns seized == actual_repay exactly.
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, x_oracle, x_oracle_policy_cap, coin_decimals_registry) = amounts_setup(scenario);
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0));
    let eth_type = type_name::get<ETH>();
    let eth = std::u64::pow(10, ETH_DECIMALS);

    let rows = vector[
      // available, debt, collateral, expected repay (== seized)
      vector[3 * eth / 10, 5 * eth, eth, 3 * eth / 10],   // partial repay
      vector[10 * eth, 7 * eth / 10, eth, 7 * eth / 10],  // capped at the debt
      vector[10 * eth, 5 * eth, eth, eth],                // capped at the collateral
      vector[7 * eth, 7 * eth, 333_333_333, 333_333_333], // collateral cap, odd amount
    ];
    let i = 0;
    while (i < vector::length(&rows)) {
      let row = vector::borrow(&rows, i);
      let (obligation, obligation_key) = rows_only_obligation(
        scenario, eth_type, *vector::borrow(row, 1), eth_type, *vector::borrow(row, 2),
      );
      let (actual_repay, seized) = forced_deleverage_evaluator::calculate_forced_deleverage_amounts<ETH, ETH>(
        &obligation, &coin_decimals_registry, &x_oracle, &clock, *vector::borrow(row, 0),
      );
      assert!(actual_repay == *vector::borrow(row, 3), i);
      assert!(seized == actual_repay, 100 + i);
      test_utils::destroy(obligation);
      test_utils::destroy(obligation_key);
      i = i + 1;
    };

    amounts_teardown(scenario_value, clock, x_oracle, x_oracle_policy_cap, coin_decimals_registry);
  }

  #[test]
  fun forced_deleverage_amount_invariants_test() {
    // Sweeps PRICE_GRID and AMOUNT_GRID on both sides for decimal gaps of
    // +3, -3, +10, -10 and 0 (same coin), checking every result against value
    // bounds rather than against the evaluator's own formula.
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, x_oracle, x_oracle_policy_cap, coin_decimals_registry) = amounts_setup(scenario);

    let checked = sweep<USDC, ETH>(scenario, &coin_decimals_registry, &mut x_oracle, &clock);
    checked = checked + sweep<ETH, USDC>(scenario, &coin_decimals_registry, &mut x_oracle, &clock);
    checked = checked + sweep<BTC, USDT>(scenario, &coin_decimals_registry, &mut x_oracle, &clock);
    checked = checked + sweep<USDT, BTC>(scenario, &coin_decimals_registry, &mut x_oracle, &clock);
    checked = checked + sweep<ETH, ETH>(scenario, &coin_decimals_registry, &mut x_oracle, &clock);
    // 608 of the 1,088 combinations are above the dust floor on both sides
    assert!(checked == 608, 0);

    amounts_teardown(scenario_value, clock, x_oracle, x_oracle_policy_cap, coin_decimals_registry);
  }

  // Oracle and decimals only, no market: USDC 6, BTC 8, ETH 9, USDT 18 decimals.
  fun amounts_setup(scenario: &mut Scenario): (Clock, XOracle, XOraclePolicyCap, CoinDecimalsRegistry) {
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    clock::set_for_testing(&mut clock, 300 * 1000);
    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, 6);
    coin_decimals_registry::register_decimals_t<BTC>(&mut coin_decimals_registry, 8);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, ETH_DECIMALS);
    coin_decimals_registry::register_decimals_t<USDT>(&mut coin_decimals_registry, 18);
    (clock, x_oracle, x_oracle_policy_cap, coin_decimals_registry)
  }

  fun amounts_teardown(
    scenario_value: Scenario,
    clock: Clock,
    x_oracle: XOracle,
    x_oracle_policy_cap: XOraclePolicyCap,
    coin_decimals_registry: CoinDecimalsRegistry,
  ) {
    clock::destroy_for_testing(clock);
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_to_address(ADMIN, x_oracle_policy_cap);
    test_scenario::end(scenario_value);
  }

  fun rows_only_obligation(
    scenario: &mut Scenario,
    debt_type: TypeName,
    debt: u64,
    collateral_type: TypeName,
    collateral: u64,
  ): (Obligation, ObligationKey) {
    let (obligation, obligation_key) = obligation::new_obligation_test(test_scenario::ctx(scenario));
    obligation::add_debt_test(&mut obligation, debt_type, debt);
    obligation::add_collateral_test(&mut obligation, collateral_type, collateral);
    (obligation, obligation_key)
  }

  // Runs the evaluator over PRICE_GRID² × AMOUNT_GRID (collateral row) ×
  // AMOUNT_GRID (available) for one coin pair. The debt row is u64::MAX, so
  // `available` is the repay cap. Returns how many cases were checked.
  fun sweep<DebtType, CollateralType>(
    scenario: &mut Scenario,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    clock: &Clock,
  ): u64 {
    let debt_type = type_name::get<DebtType>();
    let collateral_type = type_name::get<CollateralType>();
    let same_coin = debt_type == collateral_type;
    let debt_scale = (std::u64::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, debt_type)) as u256);
    let collateral_scale = (std::u64::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, collateral_type)) as u256);
    let prices = PRICE_GRID;
    let amounts = AMOUNT_GRID;
    let checked = 0;

    let c = 0;
    while (c < vector::length(&amounts)) {
      let (obligation, obligation_key) = rows_only_obligation(
        scenario, debt_type, U64_MAX, collateral_type, *vector::borrow(&amounts, c),
      );
      let i = 0;
      while (i < vector::length(&prices)) {
        x_oracle::update_price<DebtType>(x_oracle, clock, *vector::borrow(&prices, i));
        let j = 0;
        while (j < vector::length(&prices)) {
          if (!same_coin) x_oracle::update_price<CollateralType>(x_oracle, clock, *vector::borrow(&prices, j));
          // USD value of one base unit of each side, on a common scale
          let unit_d = (fixed_point32::get_raw_value(price::get_price(x_oracle, debt_type, clock)) as u256) * collateral_scale;
          let unit_c = (fixed_point32::get_raw_value(price::get_price(x_oracle, collateral_type, clock)) as u256) * debt_scale;
          let a = 0;
          while (a < vector::length(&amounts)) {
            if (check_amounts<DebtType, CollateralType>(
              &obligation, coin_decimals_registry, x_oracle, clock, unit_d, unit_c, *vector::borrow(&amounts, a),
            )) {
              checked = checked + 1;
            };
            a = a + 1;
          };
          // one price per side is the same feed when the coins match
          j = if (same_coin) { vector::length(&prices) } else { j + 1 };
        };
        i = i + 1;
      };
      test_utils::destroy(obligation);
      test_utils::destroy(obligation_key);
      c = c + 1;
    };
    checked
  }

  // Checks one evaluator result against bounds any correct 1:1 conversion meets,
  // without recomputing its formula. `unit_d` and `unit_c` are the USD values of
  // one debt and one collateral base unit on a common scale. Returns false without
  // checking when either side is worth less than one base unit of the other: the
  // evaluator rejects those amounts as dust by design.
  fun check_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    unit_d: u256,
    unit_c: u256,
    available: u64,
  ): bool {
    let (debt, _) = obligation::debt(obligation, type_name::get<DebtType>());
    let collateral = obligation::collateral(obligation, type_name::get<CollateralType>());
    let max_repay = if (available < debt) { available } else { debt };
    if ((max_repay as u256) * unit_d < unit_c || (collateral as u256) * unit_c < unit_d) return false;

    let (actual_repay, seized) = forced_deleverage_evaluator::calculate_forced_deleverage_amounts<DebtType, CollateralType>(
      obligation, coin_decimals_registry, x_oracle, clock, available,
    );
    let repaid_value = (actual_repay as u256) * unit_d;
    let seized_value = (seized as u256) * unit_c;
    assert!(actual_repay <= max_repay, 0);
    assert!(seized <= collateral, 1);
    if (actual_repay == max_repay) {
      // Full repay: seized is the floor of par. The user never gives up more value
      // than the debt removed and keeps less than one collateral unit of rounding.
      assert!(seized_value <= repaid_value, 2);
      assert!(repaid_value < seized_value + unit_c, 3);
    } else {
      // Collateral-short: taken only when the full repay needs more than all the
      // collateral. Seizes everything; the repay is par to within one unit either way.
      assert!((max_repay as u256) * unit_d >= ((collateral as u256) + 1) * unit_c, 4);
      assert!(seized == collateral, 5);
      assert!(seized_value < repaid_value + unit_d, 6);
      assert!(repaid_value < seized_value + unit_c, 7);
    };
    if (type_name::get<DebtType>() == type_name::get<CollateralType>()) {
      assert!(actual_repay == seized, 8);
    };
    true
  }

  // ── Gating ────────────────────────────────────────────────────────────────

  #[test, expected_failure(abort_code = 0x0000401, location = protocol::price)]
  fun forced_deleverage_aborts_on_stale_price_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    // advance one second WITHOUT refreshing the oracle
    clock::set_for_testing(&mut clock, 301 * 1000);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 0x0000201, location = protocol::version)]
  fun forced_deleverage_aborts_on_version_mismatch_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    // bump the shared Version object past this package's compiled version
    let version_cap = version::create_cap_for_testing(test_scenario::ctx(scenario));
    version::upgrade(&mut version, &version_cap);
    transfer::public_transfer(version_cap, ADMIN);

    test_scenario::next_tx(scenario, EXECUTOR);
    let repay_coin = coin::mint_for_testing<USDC>(100 * std::u64::pow(10, usdc_decimals), test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Interest accrual ──────────────────────────────────────────────────────

  #[test]
  fun forced_deleverage_applies_to_accrued_debt_test() {
    // Advance 100s after the borrow; the repay must apply to the accrued
    // (larger) debt, computed with the same helper repay_test uses.
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    let borrow_amount = 500 * std::u64::pow(10, usdc_decimals);
    let lend_amount = std::u64::pow(10, usdc_decimals + 4);
    let time_delta = 100;

    clock::set_for_testing(&mut clock, (300 + time_delta) * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0));
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0));

    // expected debt after accrual (same formula as repay_test)
    let growth_interest_rate = calc_growth_interest<USDC>(
      &market,
      borrow_amount,
      lend_amount - borrow_amount,
      0,
      std::u64::pow(10, 9),
      time_delta,
    );
    let increased_debt = fixed_point32::multiply_u64(borrow_amount, growth_interest_rate);
    let accrued_debt = borrow_amount + increased_debt;
    assert!(increased_debt > 0, 0);

    test_scenario::next_tx(scenario, EXECUTOR);
    let supplied = 600 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(supplied, test_scenario::ctx(scenario));
    let (remain_coin, seized_coin) = forced_deleverage::forced_deleverage<USDC, ETH>(
      &version, &mut obligation, &mut market, repay_coin, &coin_decimals_registry, &x_oracle, &clock, test_scenario::ctx(scenario),
    );

    // full repay of the accrued debt: refund = supplied − accrued_debt, row deleted
    assert!(coin::value(&remain_coin) == supplied - accrued_debt, 1);
    assert!(!obligation::has_coin_x_as_debt(&obligation, type_name::get<USDC>()), 2);
    // seized = floor(accrued_debt / 1000) at $1 vs $1000 with equal decimals
    assert!(coin::value(&seized_coin) == accrued_debt / 1000, 3);

    coin::burn_for_testing(remain_coin);
    coin::burn_for_testing(seized_coin);
    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  // ── Admin functions ───────────────────────────────────────────────────────

  #[test, expected_failure(abort_code = 0, location = sui::vec_set)]
  fun add_forced_deleverage_authority_duplicate_aborts_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, ADMIN);
    app::add_forced_deleverage_authority(&admin_cap, &mut market, EXECUTOR, test_scenario::ctx(scenario));

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }

  #[test, expected_failure(abort_code = 1, location = sui::vec_set)]
  fun remove_forced_deleverage_authority_absent_aborts_test() {
    let usdc_decimals = 9;
    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
    let (clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key) = setup(scenario, usdc_decimals, true);

    test_scenario::next_tx(scenario, ADMIN);
    app::remove_forced_deleverage_authority(&admin_cap, &mut market, @0xDD, test_scenario::ctx(scenario));

    teardown(scenario_value, clock, version, market, admin_cap, x_oracle, x_oracle_policy_cap, coin_decimals_registry, obligation, obligation_key);
  }
}
