#[test_only]
module protocol::borrow_test {
  
  use std::type_name;
  use sui::test_scenario;
  use sui::coin;
  use sui::balance;
  use sui::clock;
  use std::fixed_point32;
  use x_oracle::x_oracle;
  use x::wit_table;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::version;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::obligation;
  use protocol::market;
  use protocol::app;
  use protocol::debt_value;
  use protocol::reserve;
  use protocol::repay;
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::constants::{usdc_interest_model_params, usdc_risk_model_params, eth_interest_model_params, eth_risk_model_params};
  use protocol::oracle_t;
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use test_coin::usdt::USDT;
  use protocol::constants::usdt_interest_model_params;
  use protocol::borrow_referral::{Self, AuthorizedWitnessList};
  
  #[test]
  fun borrow_test() {
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
    let eth_interest_params = eth_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    add_interest_model_t<ETH>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &eth_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);
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

    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, eth_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == eth_amount, 0);
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    let debt_value_in_usd = debt_value::debts_value_usd(
      &obligation,
      &coin_decimals_registry,
      &x_oracle,
      &clock,
    );

    let expected_debt_value = fixed_point32::create_from_rational(699, 1);
    assert!(debt_value_in_usd == expected_debt_value, 0);

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
  fun borrow_and_repay_unequal_debt_test() {
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
    let eth_amount = 2 * std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    // mint more
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 666 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    // assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);

    // mint more
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
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
    let borrow_amount = 699 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    let reserve = market::vault(&market);
    let balance_sheets = reserve::balance_sheets(reserve);
    let balance_sheet = wit_table::borrow(balance_sheets, type_name::get<USDC>());
    let (_, reserve_debt_amount, _, _) = reserve::balance_sheet(balance_sheet);
    let market_borrow_index = market::borrow_index(&market, type_name::get<USDC>());
    
    let (obligation_debt_amount, obligation_debt_borrow_index) = obligation::debt(&obligation, type_name::get<USDC>());
    // make sure both liquidation and reserve already updated to the latest borrow_index
    // so the debt data is the latest one
    assert!(obligation_debt_borrow_index == market_borrow_index, 0);
    assert!(reserve_debt_amount != obligation_debt_amount, 0);

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

  #[test, expected_failure(abort_code = 0x0014005, location = protocol::borrow)]
  fun borrow_reached_borrow_limit_test() {
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
    let eth_interest_params = eth_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    add_interest_model_t<ETH>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &eth_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);

    // global borrow limit is only 500 USDC
    protocol::app::update_borrow_limit<USDC>(
      &admin_cap,
      &mut market,
      500 * std::u64::pow(10, 9),
    );
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);

    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, eth_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == eth_amount, 0);
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    // NOTE: this should be failed
    // because the borrow limit is only 500 USDC
    let borrow_amount = 699 * std::u64::pow(10, usdc_decimals);
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

  #[test, expected_failure]
  fun borrow_two_isolated_asset_error_test() {
    let usdc_decimals = 9;
    let usdt_decimals = 9;
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
    let usdt_interest_params = usdt_interest_model_params();
    let eth_interest_params = eth_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    add_interest_model_t<USDT>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdt_interest_params, &clock);
    add_interest_model_t<ETH>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &eth_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<USDT>(&mut coin_decimals_registry, usdt_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);

    protocol::app::update_isolated_asset_status<USDC>(&admin_cap, &mut market, true);
    protocol::app::update_isolated_asset_status<USDT>(&admin_cap, &mut market, true);

    test_scenario::next_tx(scenario, lender);
    let coin_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(coin_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == coin_amount, 0);
    coin::burn_for_testing(market_coin);
    let usdt_coin = coin::mint_for_testing<USDT>(coin_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdt_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == coin_amount, 0);
    coin::burn_for_testing(market_coin);


    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, eth_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == eth_amount, 0);
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<USDT>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDT>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
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

  #[test_only]
  struct WitnessReferral has drop {}

  #[test]
  fun borrow_with_referral_test() {
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
    let eth_interest_params = eth_interest_model_params();
    borrow_referral::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let authorized_witness_list_referral = test_scenario::take_shared<AuthorizedWitnessList>(scenario);
    app::add_referral_witness_list<WitnessReferral>(
      &admin_cap,
      &mut authorized_witness_list_referral
    );    

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    add_interest_model_t<ETH>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &eth_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);
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

    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, eth_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == eth_amount, 0);
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    app::update_borrow_fee<USDC>(
      &admin_cap,
      &mut market,
      1,
      100,
    );

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 699 * std::u64::pow(10, usdc_decimals);
    let borrow_referral_obj = borrow_referral::create_borrow_referral<USDC, WitnessReferral>(
      WitnessReferral {},
      &authorized_witness_list_referral,
      0,
      10,
      test_scenario::ctx(scenario)
    );

    let borrowed = borrow::borrow_with_referral<USDC, WitnessReferral>(
      &version, 
      &mut obligation, 
      &obligation_key, 
      &mut market, 
      &coin_decimals_registry, 
      &mut borrow_referral_obj,
      borrow_amount, 
      &x_oracle, 
      &clock, 
      test_scenario::ctx(scenario)
    );

    let base_borrow_fee_rate = fixed_point32::create_from_rational(1, 100);
    let original_borrow_fee = fixed_point32::multiply_u64(borrow_amount, base_borrow_fee_rate);

    let referral_fee_amount = borrow_referral::calc_referral_fee(
      &borrow_referral_obj,
      original_borrow_fee,
    );
    let referral_fee = borrow_referral::destroy_borrow_referral(WitnessReferral {}, borrow_referral_obj);
    assert!(balance::value(&referral_fee) == referral_fee_amount, 0);
    coin::burn_for_testing(coin::from_balance(referral_fee, test_scenario::ctx(scenario)));

    assert!(coin::value(&borrowed) == borrow_amount - original_borrow_fee, 0);
    coin::burn_for_testing(borrowed);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(authorized_witness_list_referral);
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
