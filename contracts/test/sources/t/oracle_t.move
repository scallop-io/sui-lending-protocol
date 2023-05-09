#[test_only]
module protocol_test::oracle_t {
    use oracle::switchboard_adaptor::{Self, SwitchboardBundle};
    use sui::test_scenario::{Self, Scenario};

    public fun init_t(scenario: &mut Scenario, admin: address): (SwitchboardBundle) {
        switchboard_adaptor::init_t(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);

        (test_scenario::take_shared<SwitchboardBundle>(scenario))
    }
}