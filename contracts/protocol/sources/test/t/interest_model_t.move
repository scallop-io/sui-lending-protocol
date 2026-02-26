#[test_only]
module protocol::interest_model_t {
  
  use sui::clock::Clock;
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use protocol::constants::{Self, InterestModelParams};
  use protocol::transaction_utils_t;
  
  public fun add_interest_model_t<T>(
    scenario: &mut Scenario,
    outflow_limit: u64, outflow_cycle_duration: u32, outflow_segment_duration: u32,
    market: &mut Market, admin_cap: &AdminCap, params: &InterestModelParams<T>, clock: &Clock,
  ) {
    test_scenario::next_tx(scenario, @0x0);
    let interest_model = app::create_interest_model_change<T>(
      admin_cap,
      constants::base_rate_per_sec(params),
      constants::interest_rate_scale(params),
      constants::borrow_rate_on_mid_kink(params),
      constants::mid_kink(params),
      constants::borrow_rate_on_high_kink(params),
      constants::high_kink(params),
      constants::max_borrow_rate(params),
      constants::revenue_factor(params),
      constants::borrow_weight(params),
      constants::interest_model_scale(params),
      constants::min_borrow_amount(params),
      test_scenario::ctx(scenario)
    );
    app::add_interest_model<T>(
      market,
      admin_cap,
      interest_model,
      clock,
      test_scenario::ctx(scenario),
    );
    
    transaction_utils_t::skip_epoch(scenario, 11);
    
    app::add_limiter<T>(
      admin_cap,
      market,
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
      test_scenario::ctx(scenario)
    );
    test_scenario::next_tx(scenario, @0x0);
  }
}
