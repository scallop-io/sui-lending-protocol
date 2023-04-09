#[test_only]
module protocol_test::mint_t {
  use sui::test_scenario::Scenario;
  use protocol::mint;
  use protocol::market::Market;
  use sui::coin::{Self, Coin};
  use sui::test_scenario;
  use protocol::reserve::MarketCoin;
  use sui::balance::Balance;
  use sui::clock::Clock;
  
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, market: &mut Market, coin: Coin<T>, clock: &Clock,
  ): Balance<MarketCoin<T>> {
    test_scenario::next_tx(senario, user);
    coin::into_balance(mint::mint(market, coin, clock, test_scenario::ctx(senario)))
  }
}
