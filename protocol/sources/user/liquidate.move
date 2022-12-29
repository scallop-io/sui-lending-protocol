module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use time::timestamp::{Self, TimeStamp};
  
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::evaluator;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  
  public fun liquidate<DebtType, CollateralType>(
    position: &mut Position,
    bank: &mut Bank,
    repayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    timeOracle: &TimeStamp,
  ): (Balance<DebtType>, Balance<CollateralType>) {
    let now = timestamp::timestamp(timeOracle);
    // Accrue interests for bank
    bank::accrue_all_interests(bank, now);
    // Accrue interests for position
    position::accrue_interests(position, bank);
    
    // Calc liquidation amount for the given debt type
    let repayAmount = balance::value(&repayBalance);
    let (actualRepayAmount, actualLiquidateAmount) = evaluator::actual_liquidate_amount<DebtType, CollateralType>(
      position, bank, coinDecimalsRegistry, repayAmount
    );
    
    // withdraw the collateral balance from position
    let collateralBalance = position::withdraw_collateral<CollateralType>(position, actualLiquidateAmount);
    // Reduce the debt for the position
    let debtType = get<DebtType>();
    position::decrease_debt(position, debtType, actualRepayAmount);
    
    // Put the repayCoin to the bank
    let actualRepayBalance =  balance::split(&mut repayBalance, actualRepayAmount);
    bank::handle_liquidation(bank, actualRepayBalance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (repayBalance, collateralBalance)
  }
}
