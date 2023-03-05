module protocol::repay {

  use std::type_name::{Self, TypeName};
  use sui::event::emit;
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  
  struct RepayEvent has copy, drop {
    repayer: address,
    position: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun repay<T>(
    position: &mut Position,
    bank: &mut Bank,
    clock: &Clock,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    let coinType = type_name::get<T>();
    let repayAmount = coin::value(&coin);
    
    // update bank balance sheet after repay
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    bank::handle_repay<T>(bank, coin::into_balance(coin), now);
  
    // accure interests for position
    position::accrue_interests(position, bank);
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
