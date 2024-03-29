#[test_only]
module protocol_test::withdraw_collateral_test {
    use sui::test_scenario;
    use sui::coin;
    use sui::math;
    use sui::clock;
    use x_oracle::x_oracle;
    use coin_decimals_registry::coin_decimals_registry;
    use protocol::borrow;
    use protocol::deposit_collateral;
    use protocol::mint;
    use protocol::withdraw_collateral;
    use protocol::version;
    use protocol_test::app_t::app_init;
    use protocol_test::open_obligation_t::open_obligation_t;
    use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
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
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let version = version::create_for_testing(test_scenario::ctx(scenario));
        let (market, admin_cap) = app_init(scenario);

        let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

        test_scenario::next_tx(scenario, admin);
        
        clock::set_for_testing(&mut clock, 100 * 1000);
        let eth_risk_params = eth_risk_model_params();
        add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
        let coin_decimals_registry = coin_decimals_registry_init(scenario);
        coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
                
        test_scenario::next_tx(scenario, borrower);
        let eth_amount = math::pow(10, eth_decimals);
        let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
        let (obligation, obligation_key) = open_obligation_t(scenario, &version);
        deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
        
        clock::set_for_testing(&mut clock, 200 * 1000);
        // NOTE: Oracle update is not needed--user can takes all the collateral as he will, cause there's no debt
        // x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

        test_scenario::next_tx(scenario, borrower);
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
        // 1 ETH collateral is equal to 1000 USDC
        let (obligation, obligation_key) = open_obligation_t(scenario, &version);
        deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 300 * 1000);
        x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
        x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

        test_scenario::next_tx(scenario, borrower);
        let borrow_amount = 600 * math::pow(10, usdc_decimals);
        let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
        // 600 USDC is borrowed here
        assert!(coin::value(&borrowed) == borrow_amount, 0);
        coin::burn_for_testing(borrowed);
        
        clock::set_for_testing(&mut clock, 400 * 1000);
        x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
        x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

        test_scenario::next_tx(scenario, borrower);
        let withdraw_amount = 100 * (math::pow(10, eth_decimals) / 1000);
        let withdrawed_collateral = withdraw_collateral::withdraw_collateral<ETH>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, withdraw_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
        // 100 worth of USD is withdrawed here
        // which still safe, explanation:
        // (1000 USD - 100 USD) * 0.7 collateral factor = 630 USD is the healthy debt and we just borrow 600 out of 630
        assert!(coin::value(&withdrawed_collateral) == withdraw_amount, 0);
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
}
