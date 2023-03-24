#[test_only]
module protocol_test::mint_t {
  use sui::test_scenario::Scenario;
  use protocol::mint;
  use protocol::market::Market;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::market_vault::MarketCoin;
  use sui::balance::Balance;
  
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, market: &mut Market, now: u64, coin: Coin<T>
  ): Balance<MarketCoin<T>> {
    test_scenario::next_tx(senario, user);
    mint::mint_t(market, now, coin, test_scenario::ctx(senario))
  }
}
