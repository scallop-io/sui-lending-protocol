#[test_only]
module protocol::open_obligation_t {
  
  use protocol::version::Version;
  use protocol::obligation::{ObligationKey, Obligation};
  use protocol::open_obligation::open_obligation_entry;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  
  public fun open_obligation_t(scenario: &mut Scenario, version: &Version): (Obligation, ObligationKey) {
    open_obligation_entry(version, test_scenario::ctx(scenario));
    let sender = test_scenario::sender(scenario);
    test_scenario::next_tx(scenario, sender);
    let obligation = test_scenario::take_shared<Obligation>(scenario);
    let obligation_key = test_scenario::take_from_sender<ObligationKey>(scenario);
    (obligation, obligation_key)
  }
}
