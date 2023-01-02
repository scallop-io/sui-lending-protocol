module protocol_test::coin_decimals_registry_t {
  
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use protocol::coin_decimals_registry;
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  
  #[test_only]
  public fun coin_decimals_registry_init(senario: &mut Scenario): CoinDecimalsRegistry {
    test_scenario::next_tx(senario, @0x0);
    coin_decimals_registry::init_t(test_scenario::ctx(senario));
    test_scenario::next_tx(senario, @0x0);
    test_scenario::take_shared<CoinDecimalsRegistry>(senario)
  }
}
