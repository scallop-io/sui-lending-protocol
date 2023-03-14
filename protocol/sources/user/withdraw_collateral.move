module protocol::withdraw_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::position::{Self, Position, PositionKey};
  use protocol::borrow_withdraw_evaluator;
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::balance::Balance;
  
  const EWithdrawTooMuch: u64 = 0;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    position: ID,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
  }
  
  public entry fun withdraw_collateral<T>(
    position: &mut Position,
    positionKey: &PositionKey,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ) {
    let withdrawedBalance = withdraw_collateral_<T>(
      position, positionKey, bank, coinDecimalsRegistry, clock, withdrawAmount, ctx
    );
    transfer::transfer(
      coin::from_balance(withdrawedBalance, ctx),
      tx_context::sender(ctx)
    )
  }
  
  fun withdraw_collateral_<T>(
    position: &mut Position,
    positionKey: &PositionKey,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    clock: &Clock,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ): Balance<T> {
    position::assert_key_match(position, positionKey);
    // accrue interests for banks
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    let now = clock::timestamp_ms(clock);
    bank::handle_withdraw_collateral<T>(bank, withdrawAmount, now);
  
    // accure interests for position
    position::accrue_interests(position, bank);
    
    // IF withdrawAmount bigger than max, then abort
    let maxWithdawAmount = borrow_withdraw_evaluator::max_withdraw_amount<T>(position, bank, coinDecimalsRegistry);
    assert!(withdrawAmount <= maxWithdawAmount, EWithdrawTooMuch);
    
    // withdraw collateral from position
    let withdrawedBalance = position::withdraw_collateral<T>(position, withdrawAmount);
    
    let sender = tx_context::sender(ctx);
    emit(CollateralWithdrawEvent{
      taker: sender,
      position: object::id(position),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&withdrawedBalance),
    });
    withdrawedBalance
  }
}
