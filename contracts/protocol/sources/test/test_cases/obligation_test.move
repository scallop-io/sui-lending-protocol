#[test_only]
module protocol::obligation_test {

  use std::type_name;
  use sui::test_scenario;
  use sui::coin;
  use sui::transfer;
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
  use protocol::open_obligation;
  use sui::transfer::public_transfer;
  use sui::test_utils;
  use protocol::app::add_lock_key;
  use protocol::app;
  use protocol::obligation_access::{Self, ObligationAccessStore};
  use protocol::liquidate;
  use protocol::lock_obligation;

  struct MockLockKey has drop {}

  struct AnotherMockLockKey has drop {}

  
  #[test]
  fun open_obligation_and_deposit_collateral_test() {
    let usdc_decimals = 9;
    
    let admin = @0xAD;
    let borrower = @0xBB;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);

    clock::set_for_testing(&mut clock, 100 * 1000);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);

    let (obligation, obligation_key, obligation_hot_potato) = open_obligation::open_obligation(&version, test_scenario::ctx(scenario));
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, usdc_coin, test_scenario::ctx(scenario));
    open_obligation::return_obligation(&version, obligation, obligation_hot_potato);
    transfer::public_transfer(obligation_key, borrower);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0000301, location=protocol::open_obligation)]
  fun open_obligation_with_hot_potato_and_return_invalid_obligation_test() {    
    let admin = @0xAD;
    let borrower = @0xBB;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);

    clock::set_for_testing(&mut clock, 100 * 1000);
    let usdc_risk_params = usdc_risk_model_params();
    add_risk_model_t<USDC>(scenario, &mut market, &admin_cap, &usdc_risk_params);

    let (obligation, obligation_key, obligation_hot_potato) = open_obligation::open_obligation(&version, test_scenario::ctx(scenario));
    let (obligation_two, obligation_key_two, obligation_hot_potato_two) = open_obligation::open_obligation(&version, test_scenario::ctx(scenario));
    open_obligation::return_obligation(&version, obligation_two, obligation_hot_potato);
    open_obligation::return_obligation(&version, obligation, obligation_hot_potato_two);

    transfer::public_transfer(obligation_key, borrower);
    transfer::public_transfer(obligation_key_two, borrower);


    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }  

  // lock here, works just like a hooks.
  // meant if an obligation locked, the locker contract need to be notify before doing any action with the obligation
  #[test, expected_failure(abort_code=770, location=protocol::borrow)]
  fun do_action_with_locked_obligation_error_test() {
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
    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

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

    app::add_lock_key<MockLockKey>(&admin_cap, &mut obligation_access_store);
    obligation::lock(
      &mut obligation, 
      &obligation_key, 
      &obligation_access_store, 
      true, 
      true, 
      false, 
      false, 
      true, 
      MockLockKey {}
    );

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 500 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(obligation_access_store);
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0000305, location=protocol::obligation_access)]
  fun try_lock_obligation_with_unregistered_lock_key_error_test() {
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
    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

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

    obligation::lock(
      &mut obligation, 
      &obligation_key, 
      &obligation_access_store, 
      true, 
      true, 
      false, 
      false, 
      true, 
      MockLockKey {}
    );

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 500 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(obligation_access_store);
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
  fun do_action_with_unlocked_obligation_test() {
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
    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

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

    protocol::apm::refresh_apm_state<USDC>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));
    protocol::apm::refresh_apm_state<ETH>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));    

    app::add_lock_key<MockLockKey>(&admin_cap, &mut obligation_access_store);
    obligation::lock(
      &mut obligation, 
      &obligation_key, 
      &obligation_access_store, 
      true, 
      true, 
      false, 
      false, 
      true, 
      MockLockKey {}
    );

    assert!(obligation::borrow_locked(&obligation), 0);

    obligation::unlock(
      &mut obligation, 
      &obligation_key,
      MockLockKey {}
    );

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 500 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(obligation_access_store);
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
  fun force_unlock_when_obligation_unhealthy_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let liquidator = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);
    let usdc_interest_params = usdc_interest_model_params();

    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

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
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(5, 1)); // $0.5
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    protocol::apm::refresh_apm_state<USDC>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));
    protocol::apm::refresh_apm_state<ETH>(&version, &mut market, &x_oracle, &clock, test_scenario::ctx(scenario));    

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 850 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    app::add_lock_key<MockLockKey>(&admin_cap, &mut obligation_access_store);
    obligation::lock(
      &mut obligation, 
      &obligation_key, 
      &obligation_access_store, 
      true, 
      true, 
      false, 
      false, 
      true, 
      MockLockKey {}
    );

    assert!(obligation::liquidate_locked(&obligation), 0);

    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1

    // The whitelist package will call this function to force unlock the obligation before liquidation
    lock_obligation::force_unlock(
      &version,
      &mut obligation, 
      MockLockKey {}
    );

    assert!(!obligation::liquidate_locked(&obligation), 0);

    test_scenario::next_tx(scenario, liquidator);    
    let usdc_amount = 900 * std::u64::pow(10, usdc_decimals);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));

    let (coin_debt, coin_collateral) = liquidate::liquidate<USDC, ETH>(
        &version,
        &mut obligation, 
        &mut market,
        usdc_coin,
        &coin_decimals_registry,
        &x_oracle,
        &clock,
        test_scenario::ctx(scenario),
    );

    test_utils::destroy(coin_debt);
    test_utils::destroy(coin_collateral);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(obligation_access_store);
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }
}