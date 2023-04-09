#[test_only]
module protocol_test::withdraw_collateral_t {
  
  use protocol::withdraw_collateral;
  use protocol::obligation::{Obligation, ObligationKey};
  use protocol::market::Market;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use sui::balance::Balance;
  use sui::coin;
  use sui::clock::Clock;
  
  public fun withdraw_collateral_t<T>(
    senario: &mut Scenario,
    user: address,
    obligation: &mut Obligation,
    postionKey: &ObligationKey,
    market: &mut Market,
    decimalsRegistry: &CoinDecimalsRegistry,
    withdrawAmount: u64,
    clock: &Clock,
  ): Balance<T> {
    test_scenario::next_tx(senario, user);
    coin::into_balance(withdraw_collateral::withdraw_collateral<T>(
      obligation, postionKey, market, decimalsRegistry, withdrawAmount, clock, test_scenario::ctx(senario)
    ))
  }
}
