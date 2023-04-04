module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::event::emit;
  use sui::balance;
  use protocol::market::{Self, Market};
  use protocol::reserve::MarketCoin;
  use sui::balance::Balance;
  
  struct MintEvent has copy, drop {
    minter: address,
    depositAsset: TypeName,
    depositAmount: u64,
    mintAsset: TypeName,
    mintAmount: u64,
    time: u64,
  }
  
  public fun mint_entry<T>(
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<MarketCoin<T>> {
    let mintBalance = mint(market, coin, clock, ctx);
    coin::from_balance(mintBalance, ctx)
  }
  
  public fun mint<T>(
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Balance<MarketCoin<T>> {
    let now = clock::timestamp_ms(clock);
    let depositAmount = coin::value(&coin);
    let mintBalance = market::handle_mint(market, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    
    emit(MintEvent{
      minter: sender,
      depositAsset: type_name::get<T>(),
      depositAmount,
      mintAsset: type_name::get<MarketCoin<T>>(),
      mintAmount: balance::value(&mintBalance),
      time: now,
    });
    
    mintBalance
  }
}
