#[test_only]
module protocol_test::redeem_t {
  use sui::test_scenario::Scenario;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::bank::Bank;
  use protocol::bank_vault::BankCoin;
  use protocol::redeem::redeem;
  
  public fun redeem_t<T>(
    senario: &mut Scenario, user: address, bank: &mut Bank, now: u64, coin: Coin<BankCoin<T>>
  ): Coin<T> {
    test_scenario::next_tx(senario, user);
    redeem(bank, now, coin, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<T>>(senario)
  }
}
