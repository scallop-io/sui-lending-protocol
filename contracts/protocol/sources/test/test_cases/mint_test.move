#[test_only]
module protocol::mint_test {
  
  use sui::test_scenario;
  use sui::coin::{Self, Coin};
  use sui::clock;
  use protocol::version;
  use protocol::mint;
  use protocol::reserve::MarketCoin;
  use protocol::app_t::app_init;
  use protocol::constants::usdc_interest_model_params;
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use coin_decimals_registry::coin_decimals_registry;
  use test_coin::usdc::USDC;
  
  #[test]
  fun mint_test() {
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

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));

    let (market, admin_cap) = app_init(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::increment_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    
    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    clock::increment_for_testing(&mut clock, 100 * 1000);
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);

    test_scenario::next_tx(scenario, lender_b);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    clock::increment_for_testing(&mut clock, 100 * 1000);
    mint::mint_entry(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, lender_b);
    let market_coin = test_scenario::take_from_address<Coin<MarketCoin<USDC>>>(scenario, lender_b);
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0014002, location=protocol::mint)]
  fun mint_more_than_supply_limit_failed_test() {
    let usdc_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));

    let (market, admin_cap) = app_init(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::increment_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    
    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);
    
    protocol::app::update_supply_limit<USDC>(
      &admin_cap,
      &mut market,
      1_000 * std::u64::pow(10, usdc_decimals), // 1000 USDC (max supply)
    );

    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = 10_000 * std::u64::pow(10, usdc_decimals); // 10_000 USDC
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    // this will fails, because user try to supply more than max supply
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0012001, location=protocol::mint)]
  fun mint_on_inactive_asset_failed_test() {
    let usdc_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));

    let (market, admin_cap) = app_init(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::increment_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    
    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);
    
    // set the asset to be inactive
    protocol::app::set_base_asset_active_state<USDC>(
      &admin_cap,
      &mut market,
      false,
    );

    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = 1_000 * std::u64::pow(10, usdc_decimals); // 1_000 USDC
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    // this will fails, because user try to supply on inactive pool
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }

  #[test, expected_failure(abort_code=0x0000803, location=protocol::mint)]
  fun mint_with_zero_coin_failed_test() {
    let usdc_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));

    let (market, admin_cap) = app_init(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::increment_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    
    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);

    test_scenario::next_tx(scenario, lender_a);
    // this will fails, because user try to supply on inactive pool
    let market_coin = mint::mint(&version, &mut market, coin::zero<USDC>(test_scenario::ctx(scenario)), &clock, test_scenario::ctx(scenario));
    coin::burn_for_testing(market_coin);
    
    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::end(scenario_value);
  }
}