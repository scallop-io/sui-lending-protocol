#[test_only]
module protocol_test::withdraw_collateral_test {
    use sui::test_scenario;
    use sui::coin;
    use sui::math;
    use sui::balance;
    use sui::clock::Self as clock_lib;
    use oracle::switchboard_adaptor;
    use protocol::coin_decimals_registry;
    use protocol_test::app_t::app_init;
    use protocol_test::open_obligation_t::open_obligation_t;
    use protocol_test::mint_t::mint_t;
    use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
    use protocol_test::deposit_collateral_t::deposit_collateral_t;
    use protocol_test::withdraw_collateral_t::withdraw_collateral_t;
    use protocol_test::borrow_t::borrow_t;
    use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
    use protocol_test::interest_model_t::add_interest_model_t;
    use protocol_test::risk_model_t::add_risk_model_t;
    use protocol_test::oracle_t;
    use test_coin::eth::ETH;
    use test_coin::usdc::USDC;
  
    #[test]
    public fun withdraw_collateral_without_borrowing_test() {
        // Scenario:
        // 1. `borrower` deposit collateral 1 ETH
        // 2. `borrower` withdraw collateral 1 ETH

        let eth_decimals = 9;
        
        let admin = @0xAD;
        let borrower = @0xBB;
        let scenario_value = test_scenario::begin(admin);
        let scenario = &mut scenario_value;
        let (market, admin_cap) = app_init(scenario, admin);

        let (switchboard_bundle) = oracle_t::init_t(scenario, admin);

        let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        
        clock_lib::set_for_testing(&mut clock, 100 * 1000);
        let eth_risk_params = eth_risk_model_params();
        add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
        let coin_decimals_registry = coin_decimals_registry_init(scenario);
        coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
                
        test_scenario::next_tx(scenario, borrower);
        let eth_amount = math::pow(10, eth_decimals);
        let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
        let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
        deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);
        
        clock_lib::set_for_testing(&mut clock, 200 * 1000);
        switchboard_adaptor::update_switchboard_price<ETH>(&mut switchboard_bundle, 200, 1000, 1); // $1000

        test_scenario::next_tx(scenario, borrower);
        let withdrawed_collateral = withdraw_collateral_t<ETH>(scenario, borrower, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, eth_amount, &switchboard_bundle, &clock);
        assert!(balance::value(&withdrawed_collateral) == eth_amount, 0);
        balance::destroy_for_testing(withdrawed_collateral);
        
        clock_lib::destroy_for_testing(clock);

        test_scenario::return_shared(switchboard_bundle);
        test_scenario::return_shared(coin_decimals_registry);
        test_scenario::return_shared(market);
        test_scenario::return_shared(obligation);
        test_scenario::return_to_address(admin, admin_cap);
        test_scenario::return_to_address(borrower, obligation_key);
        test_scenario::end(scenario_value);
    }
    
    #[test]
    public fun withdraw_collateral_with_borrowing_test() {
        // Scenario:
        // 0. the price of USDC = $1 and the price of ETH = $1000
        // 1. `lender` deposit 10000 USDC
        // 2. `borrower` deposit collateral 1 ETH
        // 3. `borrower` borrow 600 USDC
        // 4. `borrower` withdraw $100 worth of ETH
        //    - this action should be success, because still satisfy the 0.7 collateral factor

        let usdc_decimals = 9;
        let eth_decimals = 9;
        
        let admin = @0xAD;
        let lender = @0xAA;
        let borrower = @0xBB;
        let scenario_value = test_scenario::begin(admin);
        let scenario = &mut scenario_value;
        let (market, admin_cap) = app_init(scenario, admin);
        let usdc_interest_params = usdc_interest_model_params();

        let (switchboard_bundle) = oracle_t::init_t(scenario, admin);

        let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        
        clock_lib::set_for_testing(&mut clock, 100 * 1000);
        add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
        let eth_risk_params = eth_risk_model_params();
        add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
        let coin_decimals_registry = coin_decimals_registry_init(scenario);
        coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
        coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
        
        test_scenario::next_tx(scenario, lender);
        let usdc_amount = math::pow(10, usdc_decimals + 4);
        clock_lib::set_for_testing(&mut clock, 200 * 1000);
        let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
        let market_coin_balance = mint_t(scenario, lender, &mut market, usdc_coin, &clock);
        assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
        balance::destroy_for_testing(market_coin_balance);
        
        test_scenario::next_tx(scenario, borrower);
        let eth_amount = math::pow(10, eth_decimals);
        let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
        // 1 ETH collateral is equal to 1000 USDC
        let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
        deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);

        clock_lib::set_for_testing(&mut clock, 300 * 1000);
        switchboard_adaptor::update_switchboard_price<USDC>(&mut switchboard_bundle, 300, 1, 1); // $1
        switchboard_adaptor::update_switchboard_price<ETH>(&mut switchboard_bundle, 300, 1000, 1); // $1000

        test_scenario::next_tx(scenario, borrower);
        let borrow_amount = 600 * math::pow(10, usdc_decimals);
        let borrowed = borrow_t<USDC>(scenario, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &switchboard_bundle, &clock);
        // 600 USDC is borrowed here
        assert!(balance::value(&borrowed) == borrow_amount, 0);
        balance::destroy_for_testing(borrowed);
        
        clock_lib::set_for_testing(&mut clock, 400 * 1000);
        switchboard_adaptor::update_switchboard_price<USDC>(&mut switchboard_bundle, 400, 1, 1); // $1
        switchboard_adaptor::update_switchboard_price<ETH>(&mut switchboard_bundle, 400, 1000, 1); // $1000

        test_scenario::next_tx(scenario, borrower);
        let withdraw_amount = 100 * (math::pow(10, eth_decimals) / 1000);
        let withdrawed_collateral = withdraw_collateral_t<ETH>(scenario, borrower, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, withdraw_amount, &switchboard_bundle, &clock);
        // 100 worth of USD is withdrawed here
        // which still safe, explanation:
        // (1000 USD - 100 USD) * 0.7 collateral factor = 630 USD is the healthy debt and we just borrow 600 out of 630
        assert!(balance::value(&withdrawed_collateral) == withdraw_amount, 0);
        balance::destroy_for_testing(withdrawed_collateral);
        
        clock_lib::destroy_for_testing(clock);

        test_scenario::return_shared(switchboard_bundle);
        test_scenario::return_shared(coin_decimals_registry);
        test_scenario::return_shared(market);
        test_scenario::return_shared(obligation);
        test_scenario::return_to_address(admin, admin_cap);
        test_scenario::return_to_address(borrower, obligation_key);
        test_scenario::end(scenario_value);
    }
}
