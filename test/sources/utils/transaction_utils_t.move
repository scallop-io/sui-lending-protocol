#[test_only]
module protocol_test::transaction_utils_t {
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  
  public fun skip_epoch(scenario: &mut Scenario, number_of_skipped_epoch: u32) {
    let i = 0;
    while (i < number_of_skipped_epoch) {
      test_scenario::next_epoch(scenario, @0x0);
      i = i + 1;
    };
  }
}

