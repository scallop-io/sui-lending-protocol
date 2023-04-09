#[test_only]
module protocol_test::risk_model_t {
  
  use sui::transfer;
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol_test::constants::{Self, RiskModelParams};
  use protocol_test::transaction_utils_t;

  public fun add_risk_model_t<T>(
    senario: &mut Scenario,
    market: &mut Market, adminCap: &AdminCap, params: &RiskModelParams<T>
  ) {
    test_scenario::next_tx(senario, @0x0);
    let risk_model = app::create_risk_model_change<T>(
      adminCap,
      constants::collateral_factor(params),
      constants::liquidation_factor(params),
      constants::liquidation_penalty(params),
      constants::liquidation_discount(params),
      constants::risk_model_scale(params),
      constants::max_collateral_amount(params),
      test_scenario::ctx(senario)
    );
    app::add_risk_model<T>(
      market,
      adminCap,
      &mut risk_model,
      test_scenario::ctx(senario),
    );
    
    transaction_utils_t::skip_epoch(senario, 11);
    
    transfer::public_freeze_object(risk_model);
  }
}
