#[test_only]
module protocol_test::withdraw_collateral_t {
  
  use protocol::withdraw_collateral;
  use protocol::obligation::{Obligation, ObligationKey};
  use protocol::market::Market;
  use sui::test_scenario::Scenario;
  use sui::test_scenario;
  use sui::balance::Balance;
  use sui::coin;
  use sui::clock::Clock;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  
  public fun withdraw_collateral_t<T>(
    scenario: &mut Scenario,
    user: address,
    obligation: &mut Obligation,
    position_key: &ObligationKey,
    market: &mut Market,
    decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
  ): Balance<T> {
    test_scenario::next_tx(scenario, user);
    coin::into_balance(withdraw_collateral::withdraw_collateral<T>(
      obligation, position_key, market, decimals_registry, withdraw_amount, x_oracle, clock, test_scenario::ctx(scenario)
    ))
  }
}
