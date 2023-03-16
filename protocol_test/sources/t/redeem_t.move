#[test_only]
module protocol_test::redeem_t {
  use sui::test_scenario::Scenario;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::reserve::Reserve;
  use protocol::reserve_vault::ReserveCoin;
  use protocol::redeem;
  
  public fun redeem_t<T>(
    senario: &mut Scenario, user: address, reserve: &mut Reserve, now: u64, coin: Coin<ReserveCoin<T>>
  ): Coin<T> {
    test_scenario::next_tx(senario, user);
    redeem::redeem_t(reserve, now, coin, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<T>>(senario)
  }
}
