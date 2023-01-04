#[test_only]
module protocol_test::deposit_collateral_t {
  
  use protocol::deposit_collateral::deposit_collateral;
  use protocol::position::Position;
  use sui::coin::Coin;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  
  public fun deposit_collateral_t<T>(senario: &mut Scenario, position: &mut Position, coin: Coin<T>) {
    deposit_collateral(position, coin, test_scenario::ctx(senario))
  }
}
