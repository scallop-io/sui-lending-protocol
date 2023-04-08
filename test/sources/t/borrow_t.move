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
  use sui::coin;
  use sui::clock::Clock;
  
  public fun borrow_t<T>(
    scenario: &mut Scenario,
    postion: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    borrowAmount: u64,
    clock: &Clock,
  ): Balance<T> {
    let ctx = test_scenario::ctx(scenario);
    coin::into_balance(borrow::borrow<T>(postion, obligationKey, market, coinDecimalsRegistry, borrowAmount, clock, ctx))
  }
}
