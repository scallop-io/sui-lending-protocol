#[test_only]
module protocol::util_rate_test {

  use std::type_name;
  use std::fixed_point32;
  use sui::test_scenario;
  use sui::coin;
  use sui::clock;
  use x::wit_table;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::repay;
  use protocol::accrue_interest;
  use protocol::reserve;
  use protocol::market;
  use protocol::version;
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
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

  #[test]
  fun util_rate_saturates_when_revenue_exceeds_cash_test() {
    // Regression test for: `reserve::util_rate` returning > 1 when the accrued
    // `revenue` exceeds `cash`, which made `interest_model::calc_interest`
    // abort (invalid_util_rate_error) inside `market::update_interest_rates`
    // and bricked every accruing operation — including repay, the one that
    // restores cash.
    //
    // Scenario:
    //   lender supplies 10_000 USDC; borrower deposits 100 ETH ($100k) and
    //   borrows 9_500 USDC → utilization 95% (above the 90% high-kink, so the
    //   borrow rate is 175%/yr with the test interest model).
    //   After 20 years of accrual: interest ≈ 332_500 USDC, revenue (2%)
    //   ≈ 6_650 USDC > remaining cash of 500 USDC.
    let usdc_decimals = 9;
    let eth_decimals = 9;

    let scenario_value = test_scenario::begin(ADMIN);
    let scenario = &mut scenario_value;
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
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);

    // lender supplies 10_000 USDC
    test_scenario::next_tx(scenario, LENDER);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(std::u64::pow(10, usdc_decimals + 4), test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(market_coin);

    // borrower deposits 100 ETH and borrows 9_500 USDC (95% utilization)
    test_scenario::next_tx(scenario, BORROWER);
    let eth_coin = coin::mint_for_testing<ETH>(100 * std::u64::pow(10, eth_decimals), test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0));    // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0));  // $1000
    protocol::apm::refresh_apm_state<USDC>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));
    protocol::apm::refresh_apm_state<ETH>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));

    test_scenario::next_tx(scenario, BORROWER);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, 9500 * std::u64::pow(10, usdc_decimals), &x_oracle, &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(borrowed);

    // 20 years pass; accrue interest (accrual itself never reads util_rate)
    let twenty_years = 20 * 365 * 24 * 60 * 60;
    clock::set_for_testing(&mut clock, (300 + twenty_years) * 1000);
    accrue_interest::accrue_interest_for_market(&version, &mut market, &clock);

    // the pathological state is reached: accrued revenue exceeds cash
    let balance_sheet = wit_table::borrow(reserve::balance_sheets(market::vault(&market)), type_name::get<USDC>());
    let (cash, debt, revenue, _) = reserve::balance_sheet(balance_sheet);
    assert!(revenue > cash, 0);
    assert!(debt > 0, 1);

    // util_rate must saturate at exactly 100%, not exceed it
    let util = reserve::util_rate(market::vault(&market), type_name::get<USDC>());
    assert!(fixed_point32::get_raw_value(util) == fixed_point32::get_raw_value(fixed_point32::create_from_rational(1, 1)), 2);

    // and the recovery path works: repay (→ update_interest_rates → calc_interest)
    // no longer aborts with invalid_util_rate_error
    test_scenario::next_tx(scenario, BORROWER);
    let repay_amount = 500 * std::u64::pow(10, usdc_decimals);
    let repay_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    repay::repay<USDC>(&version, &mut obligation, &mut market, repay_coin, &clock, test_scenario::ctx(scenario));

    let balance_sheet = wit_table::borrow(reserve::balance_sheets(market::vault(&market)), type_name::get<USDC>());
    let (cash_after, debt_after, _, _) = reserve::balance_sheet(balance_sheet);
    assert!(cash_after == cash + repay_amount, 3);
    assert!(debt_after == debt - repay_amount, 4);

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
}
