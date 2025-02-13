#[test_only]
module x_oracle::primary_with_secondary_test {
    use sui::test_scenario::{Self, Scenario};
    use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};
    use sui::test_utils as sui_test_utils;
    use sui::sui::SUI;
    use sui::math;
    use sui::clock::{Self, Clock};
    use std::fixed_point32;
    use x_oracle::pyth_mock_adapter::PythRule;
    use x_oracle::supra_mock_adapter::SupraRule;
    use x_oracle::switchboard_mock_adapter::SwitchboardRule;

    const ADMIN: address = @0xAD;

    fun init_internal(scenario: &mut Scenario): (Clock, XOracle, XOraclePolicyCap) {
        x_oracle::x_oracle::init_t(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, ADMIN);
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        let x_oracle = test_scenario::take_shared<XOracle>(scenario);
        let x_oracle_policy_cap = test_scenario::take_from_address<XOraclePolicyCap>(scenario, ADMIN);

        (clock, x_oracle, x_oracle_policy_cap)
    }

    #[test]
    fun test_primary_with_secondary() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test]
    fun test_primary_with_multiple_secondary() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test]
    fun test_primary_with_multiple_secondary_with_low_price_gap() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        // Price from pyth = $10
        // Price from supra = $9.9
        // Price from svb = $10.1
        // since the gap between pyth and all the secondary is less than or equal to 1% the price update should succeed
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 99 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 101 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test]
    fun test_primary_with_multiple_secondary_with_one_high_price_gap() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        // Price from pyth = $10
        // Price from supra = $9.5 // more than threshold 1%
        // Price from svb = $10.1
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 95 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 101 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test, expected_failure(abort_code = x_oracle::price_update_policy::REQUIRE_ALL_RULES_FOLLOWED, location = x_oracle::price_update_policy)]
    fun test_primary_with_multiple_secondary_rules_incomplete_error() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        // only one secondary price are updated
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 95 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test, expected_failure(abort_code = sui::vec_set::EKeyAlreadyExists, location = sui::vec_set)]
    fun test_primary_with_multiple_secondary_rules_duplicate_error() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        // only one secondary price are updated
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 95 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 95 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    #[test, expected_failure(abort_code = x_oracle::x_oracle::PRIMARY_PRICE_NOT_QUALIFIED, location = x_oracle::x_oracle)]
    fun test_primary_with_multiple_secondary_with_all_high_price_gap_error() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        let request = x_oracle::price_update_request(&x_oracle);
        // Price from pyth = $10
        // Price from supra = $9.5 // more than threshold 1%
        // Price from svb = $11 // more than threshold 1%
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 95 * math::pow(10, x_oracle::price_feed::decimals()) / 10, 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 11 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0); // check if the price accruately updated

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }
}