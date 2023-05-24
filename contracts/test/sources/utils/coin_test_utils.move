#[test_only]
module protocol_test::coin_test_utils {
  use sui::test_scenario::Scenario;
  use sui::coin::Coin;
  use sui::coin;
  use sui::test_scenario;
  
  public fun mint_test_coin<T>(senario: &mut Scenario, amount: u64): Coin<T> {
    coin::mint_for_testing<T>(amount, test_scenario::ctx(senario))
  }
  
  public fun destory_test_coin<T>(coin: Coin<T>) {
    coin::burn_for_testing(coin);
  }
}
