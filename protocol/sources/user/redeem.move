module protocol::redeem {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use protocol::market::{Self, Market};
  use protocol::reserve::MarketCoin;
  
  struct RedeemEvent has copy, drop {
    redeemer: address,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
    burnAsset: TypeName,
    burnAmount: u64,
    time: u64,
  }
  
  public fun redeem_entry<T>(
    market: &mut Market,
    coin: Coin<MarketCoin<T>>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let coin = redeem(market, clock, coin, ctx);
    transfer::public_transfer(coin, tx_context::sender(ctx));
  }
  
  public fun redeem<T>(
    market: &mut Market,
    coin: Coin<MarketCoin<T>>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    let now = clock::timestamp_ms(clock);
    let marketCoinAmount = coin::value(&coin);
    let redeemBalance = market::handle_redeem(market, coin::into_balance(coin), now);
    
    emit(RedeemEvent {
      redeemer: tx_context::sender(ctx),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&redeemBalance),
      burnAsset: type_name::get<MarketCoin<T>>(),
      burnAmount: marketCoinAmount,
      time: now
    });
    coin::from_balance(redeemBalance, ctx)
  }
}
