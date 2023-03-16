#[test_only]
module protocol_test::app_test {
  use sui::test_scenario::{Self, Scenario};
  use protocol::reserve::Reserve;
  use protocol::app::{Self, AdminCap};
  
  public fun app_init(senario: &mut Scenario, admin: address): (Reserve, AdminCap) {
    test_scenario::next_tx(senario, admin);
    app::init_t(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, admin);
    let adminCap = test_scenario::take_from_sender<AdminCap>(senario);
    let reserve = test_scenario::take_shared<Reserve>(senario);
    (reserve, adminCap)
  }
}
