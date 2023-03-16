#[test_only]
module protocol_test::mint_t {
  use sui::test_scenario::Scenario;
  use protocol::mint;
  use protocol::reserve::Reserve;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::reserve_vault::ReserveCoin;
  use sui::balance::Balance;
  
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, reserve: &mut Reserve, now: u64, coin: Coin<T>
  ): Balance<ReserveCoin<T>> {
    test_scenario::next_tx(senario, user);
    mint::mint_t(reserve, now, coin, test_scenario::ctx(senario))
  }
}
