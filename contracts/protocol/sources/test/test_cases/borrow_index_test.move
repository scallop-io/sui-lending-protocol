#[test_only]
module protocol::borrow_index_test {

  use std::fixed_point32;
  use std::type_name;
  use sui::test_scenario;
  use sui::coin;
  use sui::clock;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use math::fixed_point32_empower;
  use protocol::version;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::accrue_interest;
  use protocol::market;
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol::oracle_t;
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  #[test]
  #[allow(deprecated_usage)]
  public fun borrow_index_test() {
    // Scenario:
    // 0. the price of USDC = $1 and the price of ETH = $1000
    // 1. `lender` deposit 10000 USDC
    // 2. `borrower` deposit collateral 1 ETH
    // 3. `borrower` borrow 699 USDC
    //    - this action is success, because the collateral of the borrower is worth of 1000 USD. 
    //      and 699 USDC borrow still satisfy 0.7 collateral factor

    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);
    let usdc_interest_params = usdc_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals + 4);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = std::u64::pow(10, usdc_decimals + 4);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    test_scenario::next_tx(scenario, borrower);
    let initial_borrow_index = market::get_current_market_borrow_index_and_round_up(&market, type_name::get<USDC>());

    let time = 60 * 60 * 24 * 365 * 1000 + 300 * 1000;
    clock::set_for_testing(&mut clock, time);
    accrue_interest::accrue_interest_for_market(&version, &mut market, &clock);
    let borrow_index = market::get_current_market_borrow_index_and_round_up(&market, type_name::get<USDC>());
    let expected_borrow_index = 4 * initial_borrow_index;
    let index_diff = if (borrow_index > expected_borrow_index) {
      borrow_index - expected_borrow_index
    } else {
      expected_borrow_index - borrow_index
    };
    let index_diff_rate = fixed_point32::create_from_rational(index_diff, expected_borrow_index);
    let index_precision = fixed_point32::create_from_rational(1, std::u64::pow(10, 8));
    assert!(
      fixed_point32_empower::gte(index_precision, index_diff_rate),
      0
    );


    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }
}
