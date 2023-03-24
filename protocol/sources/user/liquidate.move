module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use sui::clock::{Self, Clock};
  
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::liquidation_evaluator::liquidation_amounts;
  
  const ECantBeLiquidated: u64 = 0;
  
  public fun liquidate<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    let now = clock::timestamp_ms(clock);
    liquidate_(obligation, market, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  #[test_only]
  public fun liquidate_t<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    liquidate_(obligation, market, availableRepayBalance, coinDecimalsRegistry, now)
  }
  
  fun liquidate_<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    // Accrue interests for market
    market::accrue_all_interests(market, now);
    // Accrue interests for obligation
    obligation::accrue_interests(obligation, market);
    
    // Calc liquidation amounts for the given debt type
    let availableRepayAmount = balance::value(&availableRepayBalance);
    let (repayOnBehalf, repayMarket, liqAmount) =
      liquidation_amounts<DebtType, CollateralType>(obligation, market, coinDecimalsRegistry, availableRepayAmount);
    assert!(liqAmount > 0, ECantBeLiquidated);
    
    // withdraw the collateral balance from obligation
    let collateralBalance = obligation::withdraw_collateral<CollateralType>(obligation, liqAmount);
    // Reduce the debt for the obligation
    let debtType = get<DebtType>();
    obligation::decrease_debt(obligation, debtType, repayOnBehalf);
    
    // Put the repay and market balance to the market
    let repayOnBeHalfBalance = balance::split(&mut availableRepayBalance, repayOnBehalf);
    let marketBalance = balance::split(&mut availableRepayBalance, repayMarket);
    market::handle_liquidation(market, repayOnBeHalfBalance, marketBalance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (availableRepayBalance, collateralBalance)
  }
}
