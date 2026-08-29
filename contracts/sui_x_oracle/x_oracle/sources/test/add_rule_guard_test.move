#[test_only]
module x_oracle::add_rule_guard_test {
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

    // the second primary rule must be rejected by the add-time guard itself, which
    // raises PRIMARY_RULE_ALREADY_EXISTS rather than the ONLY_SUPPORT_ONE_PRIMARY that
    // determine_price uses. no price update request is built here either, so this
    // cannot be satisfied by an abort raised during a price update.
    #[test, expected_failure(abort_code = x_oracle::x_oracle::PRIMARY_RULE_ALREADY_EXISTS, location = x_oracle::x_oracle)]
    fun test_add_second_primary_rejected_at_add_time() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    // the guard must count primary rules only: registering the primary rule after
    // two secondary rules already exist has to succeed and produce a usable price.
    #[test]
    fun test_add_primary_after_two_secondaries() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);

        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::pyth_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::supra_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0);

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    // swapping the primary rule on an asset that carries two secondary rules:
    // remove-then-add is the only safe ordering, and the asset must keep updating afterwards.
    #[test]
    fun test_swap_primary_with_two_secondaries() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        clock::set_for_testing(&mut clock, 1000 * 1000);

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_secondary_price_update_rule_v2<SUI, SwitchboardRule>(&mut x_oracle, &x_oracle_policy_cap);

        x_oracle::remove_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::remove_secondary_price_update_rule_v2<SUI, SupraRule>(&mut x_oracle, &x_oracle_policy_cap);

        let request = x_oracle::price_update_request(&x_oracle);
        x_oracle::supra_mock_adapter::update_price_as_primary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::switchboard_mock_adapter::update_price_as_secondary<SUI>(&mut request, 10 * math::pow(10, x_oracle::price_feed::decimals()), 1000);
        x_oracle::confirm_price_update_request<SUI>(&mut x_oracle, request, &clock);

        assert!(fixed_point32::multiply_u64(1, x_oracle::test_utils::get_price<SUI>(&x_oracle, &clock)) == 10, 0);

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }

    // re-adding the same rule type is already rejected by the underlying VecSet,
    // before the primary count guard is reached.
    #[test, expected_failure(abort_code = sui::vec_set::EKeyAlreadyExists, location = sui::vec_set)]
    fun test_add_duplicate_primary_rule() {
        let scenario_value = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_value;

        let (clock, x_oracle, x_oracle_policy_cap) = init_internal(scenario);
        x_oracle::init_rules_df_if_not_exist(&x_oracle_policy_cap, &mut x_oracle, test_scenario::ctx(scenario));

        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);
        x_oracle::add_primary_price_update_rule_v2<SUI, PythRule>(&mut x_oracle, &x_oracle_policy_cap);

        sui_test_utils::destroy(clock);
        sui_test_utils::destroy(x_oracle);
        sui_test_utils::destroy(x_oracle_policy_cap);
        test_scenario::end(scenario_value);
    }
}
