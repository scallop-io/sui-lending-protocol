#[test_only]
module protocol_test::mint_t {
  use sui::test_scenario::Scenario;
  use protocol::mint;
  use protocol::bank::Bank;
  use sui::coin::Coin;
  use sui::test_scenario;
  use protocol::bank_vault::BankCoin;
  use sui::balance::Balance;
  
  public fun mint_t<T>(
    senario: &mut Scenario, user: address, bank: &mut Bank, now: u64, coin: Coin<T>
  ): Balance<BankCoin<T>> {
    test_scenario::next_tx(senario, user);
    mint::mint_t(bank, now, coin, test_scenario::ctx(senario))
  }
}
