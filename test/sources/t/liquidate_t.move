#[test_only]
module protocol_test::liquidate_t {
  
  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use protocol::liquidate;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::Coin;
  use oracle::switchboard_adaptor::SwitchboardBundle;
  
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    repayCoin: Coin<DebtType>,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    liquidate::liquidate<DebtType, CollateralType>(obligation, market, repayCoin, coinDecimalsRegistry, switchboard_bundle, clock, ctx)
  }
}
