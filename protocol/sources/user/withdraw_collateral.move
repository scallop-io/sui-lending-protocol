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
  use protocol::reserve::{Self, Reserve};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::balance::Balance;
  
  const EWithdrawTooMuch: u64 = 0;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    obligation: ID,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
  }
  
  public entry fun withdraw_collateral<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    reserve: &mut Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    let withdrawedBalance = withdraw_collateral_<T>(
      obligation, obligationKey, reserve, coinDecimalsRegistry, now, withdrawAmount, ctx
    );
    transfer::transfer(
      coin::from_balance(withdrawedBalance, ctx),
      tx_context::sender(ctx)
    )
  }
  
  #[test_only]
  public fun withdraw_collateral_t<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    reserve: &mut Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ): Balance<T> {
    withdraw_collateral_<T>(
      obligation, obligationKey, reserve, coinDecimalsRegistry, now, withdrawAmount, ctx
    )
  }
  
  fun withdraw_collateral_<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    reserve: &mut Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ): Balance<T> {
    obligation::assert_key_match(obligation, obligationKey);
    // accrue interests for reserves
    // Always update reserve state first
    // Because interest need to be accrued first before other operations
    reserve::handle_withdraw_collateral<T>(reserve, withdrawAmount, now);
  
    // accure interests for obligation
    obligation::accrue_interests(obligation, reserve);
    
    // IF withdrawAmount bigger than max, then abort
    let maxWithdawAmount = borrow_withdraw_evaluator::max_withdraw_amount<T>(obligation, reserve, coinDecimalsRegistry);
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
    withdrawedBalance
  }
}
