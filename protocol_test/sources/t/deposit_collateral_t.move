#[test_only]
module protocol_test::deposit_collateral_t {
  
  use protocol::deposit_collateral::deposit_collateral;
  use protocol::position::Position;
  use sui::coin::Coin;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use protocol::bank::Bank;
  
  public fun deposit_collateral_t<T>(senario: &mut Scenario, position: &mut Position, bank: &mut Bank, coin: Coin<T>) {
    deposit_collateral(position, bank, coin, test_scenario::ctx(senario))
  }
}
