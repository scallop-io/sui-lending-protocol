module protocol::repay {

  use std::type_name::{Self, TypeName};
  use sui::event::emit;
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  
  struct RepayEvent has copy, drop {
    repayer: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun repay<T>(
    obligation: &mut Obligation,
    market: &mut Market,
    clock: &Clock,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    repay_(obligation, market, now, coin, ctx)
  }
  
  #[test_only]
  public fun repay_t<T>(
    obligation: &mut Obligation,
    market: &mut Market,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    repay_(obligation, market, now, coin, ctx)
  }
  
  fun repay_<T>(
    obligation: &mut Obligation,
    market: &mut Market,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let coinType = type_name::get<T>();
    let repayAmount = coin::value(&coin);
    
    // update market balance sheet after repay
    // Always update market state first
    // Because interest need to be accrued first before other operations
    market::handle_repay<T>(market, coin::into_balance(coin), now);
  
    // accure interests for obligation
    obligation::accrue_interests(obligation, market);
    // remove debt according to repay amount
    obligation::decrease_debt(obligation, coinType, repayAmount);
    
    emit(RepayEvent {
      repayer: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coinType,
      amount: repayAmount,
      time: now,
    })
  }
}
