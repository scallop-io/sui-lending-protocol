#[test_only]
module protocol_test::withdraw_collateral_t {
  
  use protocol::withdraw_collateral;
  use protocol::position::{Position, PositionKey};
  use protocol::reserve::Reserve;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use sui::balance::Balance;
  
  public fun withdraw_collateral_t<T>(
    senario: &mut Scenario,
    user: address,
    position: &mut Position,
    postionKey: &PositionKey,
    reserve: &mut Reserve,
    decimalsRegistry: &CoinDecimalsRegistry,
    withdrawAmount: u64,
    now: u64,
  ): Balance<T> {
    test_scenario::next_tx(senario, user);
    withdraw_collateral::withdraw_collateral_t<T>(
      position, postionKey, reserve, decimalsRegistry, now, withdrawAmount, test_scenario::ctx(senario)
    )
  }
}
