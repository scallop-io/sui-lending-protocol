#[test_only]
module protocol_test::borrow_test {
  
  use std::type_name;
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::clock;
  use x_oracle::x_oracle;
  use x::wit_table;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::version;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::obligation;
  use protocol::market;
  use protocol::reserve;
  use protocol::repay;
  use protocol_test::app_t::app_init;
  use protocol_test::open_obligation_t::open_obligation_t;
  use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol_test::oracle_t;
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use protocol_test::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  #[test]
  public fun borrow_test() {
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
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = math::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * math::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);
    
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

  #[test]
  #[expected_failure]
  public fun borrow_and_repay_unequal_debt_test() {
    // Scenario:
    // 0. the price of USDC = $1 and the price of ETH = $1000
    // 1. `lender` supply 10000 USDC
    // 2. `borrower` deposit collateral 2 ETH
    // 3. `borrower` borrow 699 USDC
    //    - this action is success, because the collateral of the borrower is worth of 1000 USD. 
    //      and 699 USDC borrow still satisfy 0.7 collateral factor
    // 4. `lender` supply another 10000 USDC
    //    - the purpose is we want to accrue the interest in reserve to reproduce the problem
    // 5. `lender` supply another 10000 USDC for the 2nd time
    //    - the purpose is we want to accrue the interest in reserve to reproduce the problem
    // 6. `borrower` borrow another 699 USDC for the 2nd time
    //    - this time we want to accrue both interest in reserve and obligation. 
    //      while it's already the 3rd calculation of the interest in reserve, 
    //      and it's just the 1st calculation for the interest in obligation
    // 7. `borrower` repay all the debt based on the amount of debt in the obligation
    //    Here's the problem will appear, the debt in the reserve and obligation is differents
    //    Although both calculation using the same formula, but because of the rounded down has been done in every calculation
    //    makes the result of the reserve debt will be slightly lower than the sum of all debt in all obligations.
    
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
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = 2 * math::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * math::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    // mint more
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 666 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    // assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);

    // mint more
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 999 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    // assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);

    // borrow more
    clock::set_for_testing(&mut clock, 1500 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * math::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    let reserve = market::vault(&market);
    let balance_sheets = reserve::balance_sheets(reserve);
    let balance_sheet = wit_table::borrow(balance_sheets, type_name::get<USDC>());
    let (_, reserve_debt_amount, _, _) = reserve::balance_sheet(balance_sheet);
    let market_borrow_index = market::borrow_index(&market, type_name::get<USDC>());
    std::debug::print(&reserve_debt_amount);
    std::debug::print(&market_borrow_index);
    
    let (obligation_debt_amount, obligation_debt_borrow_index) = obligation::debt(&obligation, type_name::get<USDC>());
    std::debug::print(&obligation_debt_amount);
    std::debug::print(&obligation_debt_borrow_index);

    let repay_amount = obligation_debt_amount;
    let usdc_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    repay::repay<USDC>(&version, &mut obligation, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));    
    
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
