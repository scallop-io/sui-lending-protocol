module protocol_test::coin_test_utils {
  #[test_only]
  use sui::test_scenario::Scenario;
  #[test_only]
  use sui::coin::Coin;
  #[test_only]
  use sui::coin;
  #[test_only]
  use sui::test_scenario;
  
  #[test_only]
  public fun mint_test_coin<T>(senario: &mut Scenario, amount: u64): Coin<T> {
    coin::mint_for_testing<T>(amount, test_scenario::ctx(senario))
  }
  
  #[test_only]
  public fun destory_test_coin<T>(coin: Coin<T>) {
    coin::destroy_for_testing(coin);
  }
}
