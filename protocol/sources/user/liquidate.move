module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use time::timestamp::{Self, TimeStamp};
  
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::liquidation_evaluator::liquidation_amounts;
  
  public fun liquidate<DebtType, CollateralType>(
    position: &mut Position,
    bank: &mut Bank,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    timeOracle: &TimeStamp,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    let now = timestamp::timestamp(timeOracle);
    // Accrue interests for bank
    bank::accrue_all_interests(bank, now);
    // Accrue interests for position
    position::accrue_interests(position, bank);
    
    // Calc liquidation amounts for the given debt type
    let availableRepayAmount = balance::value(&availableRepayBalance);
    let (repayOnBehalf, repayReserve, liqAmount) =
      liquidation_amounts<DebtType, CollateralType>(position, bank, coinDecimalsRegistry, availableRepayAmount);
    
    
    // withdraw the collateral balance from position
    let collateralBalance = position::withdraw_collateral<CollateralType>(position, liqAmount);
    // Reduce the debt for the position
    let debtType = get<DebtType>();
    position::decrease_debt(position, debtType, repayOnBehalf);
    
    // Put the repay and reserve balance to the bank
    let repayOnBeHalfBalance = balance::split(&mut availableRepayBalance, repayOnBehalf);
    let reserveBalance = balance::split(&mut availableRepayBalance, repayReserve);
    bank::handle_liquidation(bank, repayOnBeHalfBalance, reserveBalance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (availableRepayBalance, collateralBalance)
  }
}
