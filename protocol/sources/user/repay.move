module protocol::repay {

  use std::type_name::{Self, TypeName};
  use sui::event::emit;
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use protocol::position::{Self, Position};
  use protocol::reserve::{Self, Reserve};
  
  struct RepayEvent has copy, drop {
    repayer: address,
    position: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun repay<T>(
    position: &mut Position,
    reserve: &mut Reserve,
    clock: &Clock,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    repay_(position, reserve, now, coin, ctx)
  }
  
  #[test_only]
  public fun repay_t<T>(
    position: &mut Position,
    reserve: &mut Reserve,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    repay_(position, reserve, now, coin, ctx)
  }
  
  fun repay_<T>(
    position: &mut Position,
    reserve: &mut Reserve,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let coinType = type_name::get<T>();
    let repayAmount = coin::value(&coin);
    
    // update reserve balance sheet after repay
    // Always update reserve state first
    // Because interest need to be accrued first before other operations
    reserve::handle_repay<T>(reserve, coin::into_balance(coin), now);
  
    // accure interests for position
    position::accrue_interests(position, reserve);
    // remove debt according to repay amount
    position::decrease_debt(position, coinType, repayAmount);
    
    emit(RepayEvent {
      repayer: tx_context::sender(ctx),
      position: object::id(position),
      asset: coinType,
      amount: repayAmount,
      time: now,
    })
  }
}
