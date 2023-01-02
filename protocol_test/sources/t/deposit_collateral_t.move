module protocol_test::deposit_collateral_t {
  
  use protocol::deposit_collateral::deposit_collateral;
  use protocol::position::Position;
  use sui::coin::Coin;
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use sui::test_scenario;
  
  #[test_only]
  public fun deposit_collateral_t<T>(senario: &mut Scenario, position: &mut Position, coin: Coin<T>) {
    deposit_collateral(position, coin, test_scenario::ctx(senario))
  }
}
