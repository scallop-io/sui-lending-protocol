module protocol_test::borrow_t {
  
  use protocol::borrow;
  use protocol::position::Position;
  use protocol::bank::Bank;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use protocol::position::PositionKey;
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use sui::balance::Balance;
  
  #[test_only]
  public fun borrow_t<T>(
    scenario: &mut Scenario,
    postion: &mut Position,
    positionKey: &PositionKey,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    borrowAmount: u64,
  ): Balance<T> {
    let ctx = test_scenario::ctx(scenario);
    borrow::borrow_<T>(postion, positionKey, bank, coinDecimalsRegistry, now, borrowAmount, ctx)
  }
}
