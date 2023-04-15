#[test_only]
module protocol_test::borrow_test {
  
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::balance;
  use sui::clock::Self as clock_lib;
  use protocol_test::app_t::app_init;
  use protocol_test::open_obligation_t::open_obligation_t;
  use protocol_test::mint_t::mint_t;
  use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol_test::deposit_collateral_t::deposit_collateral_t;
  use protocol_test::borrow_t::borrow_t;
  use protocol::coin_decimals_registry;
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use protocol_test::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  #[test]
  public fun borrow_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let (market, admin_cap) = app_init(scenario, admin);
    let usdc_interest_params = usdc_interest_model_params();

    let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    
    clock_lib::increment_for_testing(&mut clock, 100);
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock_lib::increment_for_testing(&mut clock, 100);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin_balance = mint_t(scenario, lender, &mut market, usdc_coin, &clock);
    assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
    balance::destroy_for_testing(market_coin_balance);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = math::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
    deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);
  
    test_scenario::next_tx(scenario, borrower);
    clock_lib::increment_for_testing(&mut clock, 100);
    let borrow_amount = 699 * math::pow(10, usdc_decimals);
    let borrowed = borrow_t<USDC>(scenario, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &clock);
    assert!(balance::value(&borrowed) == borrow_amount, 0);
    balance::destroy_for_testing(borrowed);
    
    clock_lib::destroy_for_testing(clock);

    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }
}
