#[test_only]
module protocol_test::interest_model_t {
  
  use sui::test_scenario::{Self, Scenario};
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol_test::constants::{Self, InterestModelParams};
  use protocol_test::transaction_utils_t;
  use protocol::interest_model::InterestModel;
  
  public fun add_interest_model_t<T>(
    scenario: &mut Scenario,
    market: &mut Market, adminCap: &AdminCap, params: &InterestModelParams<T>, now: u64,
  ) {
    test_scenario::next_tx(scenario, @0x0);
    app::create_interest_model_change<T>(
      adminCap,
      constants::base_rate_per_sec(params),
      constants::low_slope(params),
      constants::kink(params),
      constants::high_slope(params),
      constants::revenue_factor(params),
      constants::interest_model_scale(params),
      constants::min_borrow_amount(params),
      test_scenario::ctx(scenario)
    );
    
    transaction_utils_t::skip_epoch(scenario, 11);

    let interestModelChange = test_scenario::take_shared<OneTimeLockValue<InterestModel>>(scenario);
    app::add_interest_model_t<T>(
      market,
      adminCap,
      &mut interestModelChange,
      now,
      test_scenario::ctx(scenario),
    );
    test_scenario::return_shared(interestModelChange);
  }
}
