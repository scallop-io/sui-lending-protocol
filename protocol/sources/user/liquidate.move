/// TODO: add events for liquidation
module protocol::liquidate {
  
  use std::type_name::get;
  use sui::balance;
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
  use oracle::switchboard_adaptor::SwitchboardBundle;
  use whitelist::whitelist;

  const ECantBeLiquidated: u64 = 0x30001;
  
  public entry fun liquidate_entry<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let (remain_coin, collateral_coin) = liquidate<DebtType, CollateralType>(obligation, market, available_repay_coin, coin_decimals_registry, switchboard_bundle, clock, ctx);
    transfer::public_transfer(remain_coin, tx_context::sender(ctx));
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));
  }
  
  public fun liquidate<DebtType, CollateralType>(
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    // check if sender is in whitelist
    whitelist::in_whitelist(market::uid(market), tx_context::sender(ctx));

    let available_repay_balance = coin::into_balance(available_repay_coin);
    let now = clock::timestamp_ms(clock);
    // Accrue interests for market
    market::accrue_all_interests(market, now);
    // Accrue interests for obligation
    obligation::accrue_interests(obligation, market);
    
    // Calc liquidation amounts for the given debt type
    let available_repay_amount = balance::value(&available_repay_balance);
    let (repay_on_behalf, repay_revenue, liq_amount) =
      liquidation_amounts<DebtType, CollateralType>(obligation, market, coin_decimals_registry, available_repay_amount, switchboard_bundle);
    assert!(liq_amount > 0, ECantBeLiquidated);
    
    // withdraw the collateral balance from obligation
    let collateral_balance = obligation::withdraw_collateral<CollateralType>(obligation, liq_amount);
    // Reduce the debt for the obligation
    let debt_type = get<DebtType>();
    obligation::decrease_debt(obligation, debt_type, repay_on_behalf);
    
    // Put the repay and revenue balance to the market
    let repay_on_behalf_balance = balance::split(&mut available_repay_balance, repay_on_behalf);
    let revenue_balance = balance::split(&mut available_repay_balance, repay_revenue);
    market::handle_liquidation(market, repay_on_behalf_balance, revenue_balance);
  
    // Send the remaining balance, and collateral balance to liquidator
    (
      coin::from_balance(available_repay_balance, ctx),
      coin::from_balance(collateral_balance, ctx)
    )
  }
}
