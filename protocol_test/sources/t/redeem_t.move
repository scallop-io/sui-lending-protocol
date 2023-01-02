module protocol_test::redeem_t {
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use sui::coin::Coin;
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use protocol::bank::Bank;
  #[test_only]
  use protocol::bank_vault::BankCoin;
  #[test_only]
  use protocol::redeem::redeem;
  
  #[test_only]
  public fun redeem_t<T>(
    senario: &mut Scenario, user: address, bank: &mut Bank, now: u64, coin: Coin<BankCoin<T>>
  ): Coin<T> {
    test_scenario::next_tx(senario, user);
    redeem(bank, now, coin, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<T>>(senario)
  }
}
