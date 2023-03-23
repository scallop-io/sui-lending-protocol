#[test_only]
module protocol_test::borrow_t {
  use protocol::borrow;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::test_scenario::Scenario;
  use protocol::obligation::ObligationKey;
  use sui::test_scenario;
  use sui::balance::Balance;
  
  public fun borrow_t<T>(
    scenario: &mut Scenario,
    postion: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    borrowAmount: u64,
  ): Balance<T> {
    let ctx = test_scenario::ctx(scenario);
    borrow::borrow_t<T>(postion, obligationKey, market, coinDecimalsRegistry, now, borrowAmount, ctx)
  }
}
