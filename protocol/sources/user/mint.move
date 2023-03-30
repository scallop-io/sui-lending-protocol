module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::event::emit;
  use sui::transfer;
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
  
  public entry fun mint<T>(
    market: &mut Market,
    clock: &Clock,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = clock::timestamp_ms(clock);
    let mintBalance = mint_(market, now, coin, ctx);
    transfer::public_transfer(coin::from_balance(mintBalance, ctx), tx_context::sender(ctx));
  }
  
  #[test_only]
  public fun mint_t<T>(
    market: &mut Market,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ): Balance<MarketCoin<T>> {
    mint_(market, now, coin, ctx)
  }
  
  fun mint_<T>(
    market: &mut Market,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ): Balance<MarketCoin<T>> {
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
