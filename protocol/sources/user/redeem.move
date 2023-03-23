module protocol::redeem {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use protocol::market::{Self, Market};
  use protocol::market_vault::MarketCoin;
  
  struct RedeemEvent has copy, drop {
    redeemer: address,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
    burnAsset: TypeName,
    burnAmount: u64,
    time: u64,
  }
  
  public entry fun redeem<T>(
    market: &mut Market,
    clock: &Clock,
    coin: Coin<MarketCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    redeem_(market, now, coin, ctx)
  }
  
  #[test_only]
  public fun redeem_t<T>(
    market: &mut Market,
    now: u64,
    coin: Coin<MarketCoin<T>>,
    ctx: &mut TxContext,
  ) {
    redeem_(market, now, coin, ctx)
  }
  
  fun redeem_<T>(
    market: &mut Market,
    now: u64,
    coin: Coin<MarketCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let marketCoinAmount = coin::value(&coin);
    let redeemBalance = market::handle_redeem(market, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    emit(RedeemEvent {
      redeemer: tx_context::sender(ctx),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&redeemBalance),
      burnAsset: type_name::get<MarketCoin<T>>(),
      burnAmount: marketCoinAmount,
      time: now
    });
    
    transfer::transfer(coin::from_balance(redeemBalance, ctx), sender);
  }
}
