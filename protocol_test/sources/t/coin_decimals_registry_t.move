#[test_only]
module protocol_test::coin_decimals_registry_t {
  use sui::test_scenario::Scenario;
  use protocol::coin_decimals_registry;
  use sui::test_scenario;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  
  public fun coin_decimals_registry_init(senario: &mut Scenario): CoinDecimalsRegistry {
    test_scenario::next_tx(senario, @0x0);
    coin_decimals_registry::init_t(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, @0x0);
    test_scenario::take_shared<CoinDecimalsRegistry>(senario)
  }
}
