#[test_only]
module protocol_test::liquidate_t {
  
  use protocol::liquidate;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::{Self, Coin};
  use sui::balance::Balance;
  
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    repayCoin: Coin<DebtType>,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate::liquidate_t<DebtType, CollateralType>(obligation, market, coin::into_balance(repayCoin), coinDecimalsRegistry, now)
  }
}
