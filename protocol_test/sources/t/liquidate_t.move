#[test_only]
module protocol_test::liquidate_t {
  
  use protocol::liquidate;
  use protocol::position::Position;
  use protocol::reserve::Reserve;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::{Self, Coin};
  use sui::balance::Balance;
  
  public fun liquidate_t<DebtType, CollateralType>(
    position: &mut Position,
    reserve: &mut Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    repayCoin: Coin<DebtType>,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate::liquidate_t<DebtType, CollateralType>(position, reserve, coin::into_balance(repayCoin), coinDecimalsRegistry, now)
  }
}
