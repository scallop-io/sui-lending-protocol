#[test_only]
module protocol_test::mint_t {
  use sui::test_scenario::Scenario;
  use protocol::mint::mint;
  use protocol::bank::Bank;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::bank_vault::BankCoin;
  
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, bank: &mut Bank, now: u64, coin: Coin<T>
  ): Coin<BankCoin<T>> {
    test_scenario::next_tx(senario, user);
    mint(bank, now, coin, test_scenario::ctx(senario));
    test_scenario::next_tx(senario, user);
    test_scenario::take_from_sender<Coin<BankCoin<T>>>(senario)
  }
}
