#[test_only]
module protocol_test::open_obligation_t {
  
  use protocol::obligation::{ObligationKey, Obligation};
  use protocol::open_obligation::open_obligation_entry;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  
  public fun open_obligation_t(senario: &mut Scenario, user: address): (Obligation, ObligationKey) {
    test_scenario::next_tx(senario, user);
    open_obligation_entry(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    let obligation = test_scenario::take_shared<Obligation>(senario);
    let obligationKey = test_scenario::take_from_sender<ObligationKey>(senario);
    (obligation, obligationKey)
  }
}
