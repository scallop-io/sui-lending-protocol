#[test_only]
module protocol_test::borrow_t {
  use protocol::borrow;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use sui::test_scenario::Scenario;
  use protocol::obligation::ObligationKey;
  use sui::test_scenario;
  use sui::balance::Balance;
  use sui::coin;
  use sui::clock::Clock;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  
  public fun borrow_t<T>(
    scenario: &mut Scenario,
    position: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
  ): Balance<T> {
    let ctx = test_scenario::ctx(scenario);
    coin::into_balance(borrow::borrow<T>(position, obligation_key, market, coin_decimals_registry, borrow_amount, x_oracle, clock, ctx))
  }
}
