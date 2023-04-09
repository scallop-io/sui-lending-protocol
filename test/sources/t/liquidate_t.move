#[test_only]
module protocol_test::liquidate_t {
  
  use sui::clock::Clock;
  use sui::tx_context::TxContext;
  use protocol::liquidate;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::{Self, Coin};
  
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    repayCoin: Coin<DebtType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    liquidate::liquidate<DebtType, CollateralType>(obligation, market, coin::into_balance(repayCoin), coinDecimalsRegistry, clock, ctx)
  }
}
