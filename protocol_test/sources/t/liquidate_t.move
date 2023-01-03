module protocol_test::liquidate_t {
  
  #[test_only]
  use protocol::liquidate::liquidate;
  #[test_only]
  use protocol::position::Position;
  #[test_only]
  use protocol::bank::Bank;
  #[test_only]
  use sui::coin::Coin;
  #[test_only]
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  #[test_only]
  use sui::coin;
  #[test_only]
  use sui::balance::Balance;
  
  #[test_only]
  public fun liquidate_t<DebtType, CollateralType>(
    position: &mut Position,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    repayCoin: Coin<DebtType>,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate<DebtType, CollateralType>(position, bank, coin::into_balance(repayCoin), coinDecimalsRegistry, now)
  }
}
