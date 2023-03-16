#[test_only]
module protocol_test::interest_model_t {
  
  use sui::test_scenario::{Self, Scenario};
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::reserve::Reserve;
  use protocol::app::{Self, AdminCap};
  use protocol_test::constants::{Self, InterestModelParams};
  use protocol::interest_model::InterestModel;
  
  public fun add_interest_model_t<T>(
    senario: &mut Scenario,
    reserve: &mut Reserve, adminCap: &AdminCap, params: &InterestModelParams<T>, now: u64,
  ) {
    test_scenario::next_tx(senario, @0x0);
    app::create_interest_model_change<T>(
      adminCap,
      constants::base_rate_per_sec(params),
      constants::low_slope(params),
      constants::kink(params),
      constants::high_slope(params),
      constants::reserve_factor(params),
      constants::interest_model_scale(params),
      constants::min_borrow_amount(params),
      test_scenario::ctx(senario)
    );
    
    let i = 0;
    while (i < 11) {
      test_scenario::next_epoch(senario, @0x0);
      i = i + 1;
    };
    let interestModelChange = test_scenario::take_shared<OneTimeLockValue<InterestModel>>(senario);
    app::add_interest_model_t<T>(
      reserve,
      adminCap,
      &mut interestModelChange,
      now,
      test_scenario::ctx(senario),
    );
    test_scenario::return_shared(interestModelChange);
  }
}
