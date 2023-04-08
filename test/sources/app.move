#[test_only]
module protocol_test::app_t {
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  
  public fun app_init(senario: &mut Scenario, admin: address): (Market, AdminCap) {
    test_scenario::next_tx(senario, admin);
    app::init_t(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, admin);
    let adminCap = test_scenario::take_from_sender<AdminCap>(senario);
    let market = test_scenario::take_shared<Market>(senario);
    (market, adminCap)
  }
}
