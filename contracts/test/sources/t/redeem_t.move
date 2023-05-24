#[test_only]
module protocol_test::redeem_t {
  use sui::test_scenario::Scenario;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::market::Market;
  use protocol::reserve::MarketCoin;
  use protocol::redeem;
  use sui::clock::Clock;
  
  public fun redeem_t<T>(
    senario: &mut Scenario, user: address, market: &mut Market, coin: Coin<MarketCoin<T>>, clock: &Clock,
  ): Coin<T> {
    test_scenario::next_tx(senario, user);
    redeem::redeem_entry(market, coin, clock, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<T>>(senario)
  }
}
