module protocol_test::withdraw_collateral_t {
  
  use protocol::withdraw_collateral::withdraw_collateral;
  use protocol::position::{Position, PositionKey};
  use protocol::bank::Bank;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use sui::coin::Coin;
  
  #[test_only]
  public fun withdraw_collateral_t<T>(
    senario: &mut Scenario,
    user: address,
    position: &mut Position,
    postionKey: &PositionKey,
    bank: &mut Bank,
    decimalsRegistry: &CoinDecimalsRegistry,
    withdrawAmount: u64,
    now: u64,
  ): Coin<T> {
    test_scenario::next_tx(senario, user);
    withdraw_collateral<T>(position, postionKey, bank, decimalsRegistry, now, withdrawAmount, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<T>>(senario)
  }
}