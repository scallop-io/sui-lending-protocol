module protocol_test::mint_t {
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use protocol::mint::mint;
  #[test_only]
  use protocol::bank::Bank;
  #[test_only]
  use sui::coin::Coin;
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use protocol::bank_vault::BankCoin;
  
  #[test_only]
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, bank: &mut Bank, now: u64, coin: Coin<T>
  ): Coin<BankCoin<T>> {
    test_scenario::next_tx(senario, user);
    mint(bank, now, coin, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<BankCoin<T>>>(senario)
  }
}
