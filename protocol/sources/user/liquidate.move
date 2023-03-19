module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use sui::clock::{Self, Clock};
  
  use protocol::obligation::{Self, Obligation};
  use protocol::reserve::{Self, Reserve};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::liquidation_evaluator::liquidation_amounts;
  
  const ECantBeLiquidated: u64 = 0;
  
  public fun liquidate<DebtType, CollateralType>(
    obligation: &mut Obligation,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    let now = clock::timestamp_ms(clock);
    liquidate_(obligation, reserve, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  #[test_only]
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate_(obligation, reserve, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  fun liquidate_<DebtType, CollateralType>(
    obligation: &mut Obligation,
    reserve: &mut Reserve,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    // Accrue interests for reserve
    reserve::accrue_all_interests(reserve, now);
    // Accrue interests for obligation
    obligation::accrue_interests(obligation, reserve);
    
    // Calc liquidation amounts for the given debt type
    let availableRepayAmount = balance::value(&availableRepayBalance);
    let (repayOnBehalf, repayReserve, liqAmount) =
      liquidation_amounts<DebtType, CollateralType>(obligation, reserve, coinDecimalsRegistry, availableRepayAmount);
    assert!(liqAmount > 0, ECantBeLiquidated);
    
    // withdraw the collateral balance from obligation
    let collateralBalance = obligation::withdraw_collateral<CollateralType>(obligation, liqAmount);
    // Reduce the debt for the obligation
    let debtType = get<DebtType>();
    obligation::decrease_debt(obligation, debtType, repayOnBehalf);
    
    // Put the repay and reserve balance to the reserve
    let repayOnBeHalfBalance = balance::split(&mut availableRepayBalance, repayOnBehalf);
    let reserveBalance = balance::split(&mut availableRepayBalance, repayReserve);
    reserve::handle_liquidation(reserve, repayOnBeHalfBalance, reserveBalance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (availableRepayBalance, collateralBalance)
  }
}
