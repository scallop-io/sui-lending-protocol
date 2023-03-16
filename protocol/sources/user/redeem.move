module protocol::redeem {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use protocol::reserve::{Self, Reserve};
  use protocol::reserve_vault::ReserveCoin;
  
  struct RedeemEvent has copy, drop {
    redeemer: address,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
    burnAsset: TypeName,
    burnAmount: u64,
    time: u64,
  }
  
  public entry fun redeem<T>(
    reserve: &mut Reserve,
    clock: &Clock,
    coin: Coin<ReserveCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    redeem_(reserve, now, coin, ctx)
  }
  
  #[test_only]
  public fun redeem_t<T>(
    reserve: &mut Reserve,
    now: u64,
    coin: Coin<ReserveCoin<T>>,
    ctx: &mut TxContext,
  ) {
    redeem_(reserve, now, coin, ctx)
  }
  
  fun redeem_<T>(
    reserve: &mut Reserve,
    now: u64,
    coin: Coin<ReserveCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let reserveCoinAmount = coin::value(&coin);
    let redeemBalance = reserve::handle_redeem(reserve, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    emit(RedeemEvent {
      redeemer: tx_context::sender(ctx),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&redeemBalance),
      burnAsset: type_name::get<ReserveCoin<T>>(),
      burnAmount: reserveCoinAmount,
      time: now
    });
    
    transfer::transfer(coin::from_balance(redeemBalance, ctx), sender);
  }
}
