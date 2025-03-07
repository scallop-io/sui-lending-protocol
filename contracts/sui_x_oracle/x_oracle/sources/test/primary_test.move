#[test_only]
module x_oracle::primary_test {
    use sui::test_scenario::{Self, Scenario};
    use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};
    use sui::test_utils as sui_test_utils;
    use sui::sui::SUI;
    use sui::math;
    use sui::clock::{Self, Clock};
    use std::fixed_point32;
    use x_oracle::pyth_mock_adapter::PythRule;
    use x_oracle::supra_mock_adapter::SupraRule;

    const ADMIN: address = @0xAD;

    struct ETH has drop {}

    fun init_internal(scenario: &mut Scenario): (Clock, XOracle, XOraclePolicyCap) {
        x_oracle::x_oracle::init_t(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let x_oracle = test_scenario::take_shared<XOracle>(scenario);
        let x_oracle_policy_cap = test_scenario::take_from_address<XOraclePolicyCap>(scenario, ADMIN);

        (clock, x_oracle, x_oracle_policy_cap)
    }

    #[test]
    fun test_primary() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test]
    fun test_primary_for_multiple_prices() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<ETH, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request_update_sui = x_oracle::price_update_request(&x_oracle);
        let request_update_eth = x_oracle::price_update_request(&x_oracle);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request_update_sui, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_primary<ETH>(&mut request_update_eth, 1000 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request_update_sui, &clock);
        x_oracle::confirm_price_update_request<ETH>(&mut x_oracle, request_update_eth, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    // currently we only support one primary price feed
    // this test should fail
    #[test, expected_failure(abort_code = x_oracle::x_oracle::ONLY_SUPPORT_ONE_PRIMARY, location = x_oracle::x_oracle)]
    fun test_two_primary_error() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::supra_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }
}