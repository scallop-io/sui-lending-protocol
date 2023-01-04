module protocol_test::app_test {
  #[test_only]
  use sui::test_scenario::{Self, Scenario};
  use protocol::app::{Self, AdminCap};
  use protocol::bank::Bank;
  use protocol_test::constants::{Self, RiskModelParams};
  
  #[test_only]
  public fun app_init(senario: &mut Scenario, admin: address): (Bank, AdminCap) {
    test_scenario::next_tx(senario, admin);
    app::init_t(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, admin);
    let adminCap = test_scenario::take_from_sender<AdminCap>(senario);
    let bank = test_scenario::take_shared<Bank>(senario);
    (bank, adminCap)
  }
  
  public fun add_risk_model<T>(bank: &mut Bank, adminCap: &AdminCap, params: &RiskModelParams<T>) {
    app::add_risk_model<T>(
      bank,
      adminCap,
      constants::collateral_factor(params),
      constants::liquidation_factor(params),
      constants::liquidation_panelty(params),
      constants::liquidation_discount(params),
      constants::risk_model_scale(params),
    );
  }
}
