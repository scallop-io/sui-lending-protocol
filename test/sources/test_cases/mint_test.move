#[test_only]
module protocol_test::mint_test {
  
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::balance;
  use sui::clock::Self as clock_lib;
  use protocol_test::app_t::app_init;
  use protocol_test::mint_t::mint_t;
  use protocol_test::constants::usdc_interest_model_params;
  use protocol::coin_decimals_registry;
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use test_coin::usdc::USDC;
  
  #[test]
  public fun mint_test() {
    // Scenario:
    // 1. `lender A` deposit 10000 USDC
    //    - assert that lender A get 10000 market coin of USDC
    // 2. `lender B` deposit 10000 USDC
    //    - assert that lender B get 10000 market coin of USDC

    let usdc_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;
    let lender_b = @0xBB;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let (market, admin_cap) = app_init(scenario, admin);

    let usdc_interest_params = usdc_interest_model_params();
    let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    
    clock_lib::increment_for_testing(&mut clock, 100);
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    
    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    clock_lib::increment_for_testing(&mut clock, 100);
    let market_coin_balance = mint_t(scenario, lender_a, &mut market, usdc_coin, &clock);
    assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
    balance::destroy_for_testing(market_coin_balance);

    test_scenario::next_tx(scenario, lender_b);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    clock_lib::increment_for_testing(&mut clock, 100);
    let market_coin_balance = mint_t(scenario, lender_b, &mut market, usdc_coin, &clock);
    assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
    balance::destroy_for_testing(market_coin_balance);
    
    clock_lib::destroy_for_testing(clock);

    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }
}