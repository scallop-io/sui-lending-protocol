#[test_only]
module protocol_test::oracle_t {
    use sui::test_scenario::{Self, Scenario};
    use x_oracle::x_oracle::{Self, XOracle, XOraclePolicyCap};

    public fun init_t(scenario: &mut Scenario): (XOracle, XOraclePolicyCap) {
        x_oracle::init_t(test_scenario::ctx(scenario));
        let sender = test_scenario::sender(scenario);
        test_scenario::next_tx(scenario, sender);

        (test_scenario::take_shared<XOracle>(scenario), test_scenario::take_from_address<XOraclePolicyCap>(scenario, sender))
    }

    public fun calc_scaled_price(scaled_price: u64, decimals: u8): u64 {
        assert!(decimals <= 9, 1);
        // the oracle price_feed need a scaled price with 9 decimals
        scaled_price * std::u64::pow(10, 9 - decimals)
    }
}