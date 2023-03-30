#[test_only]
module protocol_test::risk_model_t {
  
  use sui::test_scenario::{Self, Scenario};
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol_test::constants::{Self, RiskModelParams};
  use protocol::risk_model::RiskModel;
  
  public fun add_risk_model_t<T>(
    senario: &mut Scenario,
    market: &mut Market, adminCap: &AdminCap, params: &RiskModelParams<T>
  ) {
    test_scenario::next_tx(senario, @0x0);
    app::create_risk_model_change<T>(
      adminCap,
      constants::collateral_factor(params),
      constants::liquidation_factor(params),
      constants::liquidation_penalty(params),
      constants::liquidation_discount(params),
      constants::risk_model_scale(params),
      constants::max_collateral_amount(params),
      test_scenario::ctx(senario)
    );
    
    let i = 0;
    while (i < 11) {
      test_scenario::next_epoch(senario, @0x0);
      i = i + 1;
    };
    let riskModelChange = test_scenario::take_shared<OneTimeLockValue<RiskModel>>(senario);
    app::add_risk_model<T>(
      market,
      adminCap,
      &mut riskModelChange,
      test_scenario::ctx(senario),
    );
    test_scenario::return_shared(riskModelChange);
  }
}
