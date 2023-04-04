module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance::{Self, Balance};
  use sui::clock::{Self, Clock};
  
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::liquidation_evaluator::liquidation_amounts;
  use sui::coin::Coin;
  use sui::coin;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::tx_context;

  const ECantBeLiquidated: u64 = 0;
  
  public fun liquidate_entry<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let (remainCoin, collateralCoin) = liquidate<DebtType, CollateralType>(obligation, market, availableRepayBalance, coinDecimalsRegistry, clock, ctx);
    transfer::public_transfer(remainCoin, tx_context::sender(ctx));
    transfer::public_transfer(collateralCoin, tx_context::sender(ctx));
  }
  
  public fun liquidate<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    availableRepayBalance: Balance<DebtType>,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    let now = clock::timestamp_ms(clock);
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
    (
      coin::from_balance(availableRepayBalance, ctx),
      coin::from_balance(collateralBalance, ctx)
    )
  }
}
