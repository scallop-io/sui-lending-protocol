#[test_only]
module protocol_test::coin_decimals_registry_t {
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  
  public fun coin_decimals_registry_init(scenario: &mut Scenario): CoinDecimalsRegistry {
    coin_decimals_registry::init_t(test_scenario::ctx(scenario));
    let sender = test_scenario::sender(scenario);
    test_scenario::next_tx(scenario, sender);
    test_scenario::take_shared<CoinDecimalsRegistry>(scenario)
  }
}
