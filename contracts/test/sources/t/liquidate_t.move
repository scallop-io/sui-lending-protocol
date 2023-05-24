#[test_only]
module protocol_test::liquidate_t {
  
  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use protocol::liquidate;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::Coin;
  use x_oracle::x_oracle::XOracle;
  
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    repay_coin: Coin<DebtType>,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    liquidate::liquidate<DebtType, CollateralType>(obligation, market, repay_coin, coin_decimals_registry, x_oracle, clock, ctx)
  }
}
