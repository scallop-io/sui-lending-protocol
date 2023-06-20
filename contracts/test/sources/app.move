#[test_only]
module protocol_test::app_t {
  use sui::math;
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use whitelist::whitelist;
  use test_coin::usdc::USDC;
  
  public fun app_init(scenario: &mut Scenario): (Market, AdminCap) {
    app::init_t(test_scenario::ctx(scenario));
    let sender = test_scenario::sender(scenario);
    test_scenario::next_tx(scenario, sender);
    let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
    let market = test_scenario::take_shared<Market>(scenario);

    // set-up incentive rewards
    app::set_incentive_reward<USDC>(
      &adminCap,
      &mut market,
      31709791, // 10 * (10 ** 16) / (365 * 24 * 3600) / 100
      math::pow(10, 16),
      test_scenario::ctx(scenario)
    );

    whitelist::allow_all(app::ext(&adminCap, &mut market));

    (market, adminCap)
  }
}
