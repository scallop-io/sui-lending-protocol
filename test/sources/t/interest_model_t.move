#[test_only]
module protocol_test::interest_model_t {
  
  use sui::transfer;
  use sui::clock::Clock;
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol_test::constants::{Self, InterestModelParams};
  use protocol_test::transaction_utils_t;
  
  public fun add_interest_model_t<T>(
    scenario: &mut Scenario,
    outflow_limit: u64, outflow_cycle_duration: u32, outflow_segment_duration: u32,
    market: &mut Market, adminCap: &AdminCap, params: &InterestModelParams<T>, clock: &Clock,
  ) {
    test_scenario::next_tx(scenario, @0x0);
    let interest_model = app::create_interest_model_change<T>(
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
    app::add_interest_model<T>(
      market,
      adminCap,
      &mut interest_model,
      clock,
      test_scenario::ctx(scenario),
    );
    transfer::public_freeze_object(interest_model);
    
    transaction_utils_t::skip_epoch(scenario, 11);
    
    app::add_limiter<T>(
      adminCap,
      market,
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
      test_scenario::ctx(scenario)
    );
    test_scenario::next_tx(scenario, @0x0);
  }
}
