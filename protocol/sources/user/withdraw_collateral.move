module protocol::withdraw_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::borrow_withdraw_evaluator;
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::Coin;

  const EWithdrawTooMuch: u64 = 0;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    obligation: ID,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
  }
  
  public entry fun withdraw_collateral_entry<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    withdrawAmount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let withdrawedCoin = withdraw_collateral<T>(
      obligation, obligationKey, market, coinDecimalsRegistry, withdrawAmount, clock, ctx
    );
    transfer::public_transfer(withdrawedCoin, tx_context::sender(ctx));
  }
  
  public fun withdraw_collateral<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    withdrawAmount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    let now = clock::timestamp_ms(clock);

    obligation::assert_key_match(obligation, obligationKey);
    // accrue interests for markets
    // Always update market state first
    // Because interest need to be accrued first before other operations
    market::handle_withdraw_collateral<T>(market, withdrawAmount, now);
  
    // accure interests for obligation
    obligation::accrue_interests(obligation, market);
    
    // IF withdrawAmount bigger than max, then abort
    let maxWithdawAmount = borrow_withdraw_evaluator::max_withdraw_amount<T>(obligation, market, coinDecimalsRegistry);
    assert!(withdrawAmount <= maxWithdawAmount, EWithdrawTooMuch);
    
    // withdraw collateral from obligation
    let withdrawedBalance = obligation::withdraw_collateral<T>(obligation, withdrawAmount);
    
    let sender = tx_context::sender(ctx);
    emit(CollateralWithdrawEvent{
      taker: sender,
      obligation: object::id(obligation),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&withdrawedBalance),
    });
    coin::from_balance(withdrawedBalance, ctx)
  }
}
