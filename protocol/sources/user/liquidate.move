module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use sui::clock::{Self, Clock};
  
  use protocol::position::{Self, Position};
  use protocol::reserve::{Self, Reserve};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::liquidation_evaluator::liquidation_amounts;
  
  const ECantBeLiquidated: u64 = 0;
  
  public fun liquidate<DebtType, CollateralType>(
    position: &mut Position,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    let now = clock::timestamp_ms(clock);
    liquidate_(position, reserve, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  #[test_only]
  public fun liquidate_t<DebtType, CollateralType>(
    position: &mut Position,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate_(position, reserve, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  fun liquidate_<DebtType, CollateralType>(
    position: &mut Position,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    // Accrue interests for reserve
    reserve::accrue_all_interests(reserve, now);
    // Accrue interests for position
    position::accrue_interests(position, reserve);
    
    // Calc liquidation amounts for the given debt type
    let availableRepayAmount = balance::value(&availableRepayBalance);
    let (repayOnBehalf, repayReserve, liqAmount) =
      liquidation_amounts<DebtType, CollateralType>(position, reserve, coinDecimalsRegistry, availableRepayAmount);
    assert!(liqAmount > 0, ECantBeLiquidated);
    
    // withdraw the collateral balance from position
    let collateralBalance = position::withdraw_collateral<CollateralType>(position, liqAmount);
    // Reduce the debt for the position
    let debtType = get<DebtType>();
    position::decrease_debt(position, debtType, repayOnBehalf);
    
    // Put the repay and reserve balance to the reserve
    let repayOnBeHalfBalance = balance::split(&mut availableRepayBalance, repayOnBehalf);
    let reserveBalance = balance::split(&mut availableRepayBalance, repayReserve);
    reserve::handle_liquidation(reserve, repayOnBeHalfBalance, reserveBalance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (availableRepayBalance, collateralBalance)
  }
}
