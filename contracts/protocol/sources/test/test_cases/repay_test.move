#[test_only]
module protocol::repay_test {
  
  use sui::test_scenario;
  use sui::coin::{Self, Coin};
  use sui::clock;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::repay;
  use protocol::withdraw_collateral;
  use protocol::version;
  use protocol::obligation;
  use protocol::obligation_access::{Self, ObligationAccessStore};
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol::market_t::calc_growth_interest_on_obligation;
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use protocol::oracle_t;
  use decimal::decimal;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use protocol::accrue_interest;
  
  #[test]
  fun repay_test() {
    // Scenario:
    // 0. the price of USDC = $1 and the price of ETH = $1000
    // 1. `lender` deposit 10000 USDC
    // 2. `borrower` deposit collateral 1 ETH
    // 3. `borrower` borrow 100 USDC
    // 4a. 100 seconds is passed, calculated the current debt of `borrower` including the interest
    // 4b. `borrower` repay 100 USDC + expected interest
    // 5. `borrower` withdraw all collateral he has (1 ETH)
    //    - if no debt left, this function should be success
    //    - otherwise, the collateral should satisfy 70% of the debt and it will cause this withdraw function to fail

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
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    let time_delta = 100;
    clock::set_for_testing(&mut clock, 400 * 1000);
    // interest on obligation is calculated with borrow index rounded up
    // so need to use different function to calculate the growth interest
    let growth_interest_rate = calc_growth_interest_on_obligation<USDC>(
      &market,
      borrow_amount,
      usdc_amount - borrow_amount,
      0,
      decimal::from(1),
      time_delta,
    );
    let increased_debt = decimal::floor(
      decimal::mul(
        decimal::from(borrow_amount),
        growth_interest_rate
      )
    );

    let repay_amount = borrow_amount + increased_debt;
    let usdc_coin = coin::mint_for_testing<USDC>(repay_amount, test_scenario::ctx(scenario));
    repay::repay<USDC>(&version, &mut obligation, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 500 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    accrue_interest::accrue_interest_for_market(&version, &mut market, &clock);
    accrue_interest::accrue_interest_for_market_and_obligation(&version, &mut market, &mut obligation, &clock);

    // withdraw all of the collateral coin
    let withdrawed_collateral = withdraw_collateral::withdraw_collateral<ETH>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, eth_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&withdrawed_collateral) == eth_amount, 0);
    coin::burn_for_testing(withdrawed_collateral);
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0015001, location=protocol::repay)]
  fun repay_zero_coin_failed_test() {
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
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    // repay with 0 coin
    repay::repay<USDC>(&version, &mut obligation, &mut market, coin::zero(test_scenario::ctx(scenario)), &clock, test_scenario::ctx(scenario));
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[test_only]
  struct LockKey has drop {}

  #[test, expected_failure(abort_code=0x0000302, location=protocol::repay)]
  fun repay_on_locked_obligation_failed_test() {
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

    obligation_access::init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);
    protocol::app::add_lock_key<LockKey>(
        &admin_cap,
        &mut obligation_access_store,
    );
    
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
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);

    obligation::lock<LockKey>(
      &mut obligation,
      &obligation_key,
      &obligation_access_store,
      false,
      true,
      false,
      false,
      false,
      LockKey {}
    );

    // this will fails, because the obligation is locked
    repay::repay<USDC>(&version, &mut obligation, &mut market, borrowed, &clock, test_scenario::ctx(scenario));
    
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

  #[test]
  fun repay_more_than_debt_test() {
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
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 100 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);

    let extra_coin_amount = 1_000;
    let repay_coin = coin::mint_for_testing<USDC>(extra_coin_amount, test_scenario::ctx(scenario));
    coin::join(&mut repay_coin, borrowed);
    repay::repay<USDC>(&version, &mut obligation, &mut market, repay_coin, &clock, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, borrower);

    let returned_coin = test_scenario::take_from_address<Coin<USDC>>(scenario, borrower);
    assert!(coin::value(&returned_coin) == extra_coin_amount, 0);
    coin::burn_for_testing(returned_coin);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

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
