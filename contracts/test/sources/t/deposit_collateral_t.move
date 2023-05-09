#[test_only]
module protocol_test::deposit_collateral_t {
  
  use protocol::deposit_collateral::deposit_collateral;
  use protocol::obligation::Obligation;
  use sui::coin::Coin;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use protocol::market::Market;
  
  public fun deposit_collateral_t<T>(scenario: &mut Scenario, obligation: &mut Obligation, market: &mut Market, coin: Coin<T>) {
    deposit_collateral(obligation, market, coin, test_scenario::ctx(scenario))
  }
}
