module protocol::liquidate {
  
  use std::type_name::{Self, TypeName};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::balance;
  use sui::transfer;
  use sui::event::emit;
  
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::liquidation_evaluator::liquidation_amounts;
  use protocol::error;
  use x_oracle::x_oracle::XOracle;
  use whitelist::whitelist;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;

  struct LiquidateEvent has copy, drop {
    liquidator: address,
    obligation: ID,
    debt_type: TypeName,
    collateral_type: TypeName,
    repay_on_behalf: u64,
    repay_revenue: u64,
    liq_amount: u64,
  }
  
  public entry fun liquidate_entry<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let (remain_coin, collateral_coin) = liquidate<DebtType, CollateralType>(version, obligation, market, available_repay_coin, coin_decimals_registry, x_oracle, clock, ctx);
    transfer::public_transfer(remain_coin, tx_context::sender(ctx));
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));
  }
  
  public fun liquidate<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {
    // Check the version
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    // check if obligation is locked
    assert!(
      obligation::liquidate_locked(obligation) == false,
      error::obligation_locked()
    );

    let available_repay_balance = coin::into_balance(available_repay_coin);
    let now = clock::timestamp_ms(clock) / 1000;
    // Accrue interests for market
    market::accrue_all_interests(market, now);
    // Accrue interests & rewards for obligation
    obligation::accrue_interests_and_rewards(obligation, market);
    
    // Calc liquidation amounts for the given debt type
    let available_repay_amount = balance::value(&available_repay_balance);
    let (repay_on_behalf, repay_revenue, liq_amount) =
      liquidation_amounts<DebtType, CollateralType>(obligation, market, coin_decimals_registry, available_repay_amount, x_oracle, clock);
    assert!(liq_amount > 0, error::unable_to_liquidate_error());
    
    // withdraw the collateral balance from obligation
    let collateral_balance = obligation::withdraw_collateral<CollateralType>(obligation, liq_amount);
    // Reduce the debt for the obligation
    let debt_type = type_name::get<DebtType>();
    obligation::decrease_debt(obligation, debt_type, repay_on_behalf);
    
    // Put the repay and revenue balance to the market
    let repay_on_behalf_balance = balance::split(&mut available_repay_balance, repay_on_behalf);
    let revenue_balance = balance::split(&mut available_repay_balance, repay_revenue);
    market::handle_liquidation<DebtType, CollateralType>(market, repay_on_behalf_balance, revenue_balance, liq_amount);

    emit(LiquidateEvent {
      liquidator: tx_context::sender(ctx),
      obligation: object::id(obligation),
      debt_type: type_name::get<DebtType>(),
      collateral_type: type_name::get<CollateralType>(),
      repay_on_behalf,
      repay_revenue,
      liq_amount,
    });

    // Send the remaining balance, and collateral balance to liquidator
    (
      coin::from_balance(available_repay_balance, ctx),
      coin::from_balance(collateral_balance, ctx)
    )
  }
}
