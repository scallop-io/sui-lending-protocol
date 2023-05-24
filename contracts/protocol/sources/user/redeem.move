module protocol::redeem {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::reserve::MarketCoin;
  use protocol::error;
  use whitelist::whitelist;

  struct RedeemEvent has copy, drop {
    redeemer: address,
    withdraw_asset: TypeName,
    withdraw_amount: u64,
    burn_asset: TypeName,
    burn_amount: u64,
    time: u64,
  }
  
  public fun redeem_entry<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<MarketCoin<T>>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let coin = redeem(version, market, coin, clock, ctx);
    transfer::public_transfer(coin, tx_context::sender(ctx));
  }
  
  public fun redeem<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<MarketCoin<T>>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    // check version
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let now = clock::timestamp_ms(clock) / 1000;
    let market_coin_amount = coin::value(&coin);
    let redeem_balance = market::handle_redeem(market, coin::into_balance(coin), now);
    
    emit(RedeemEvent {
      redeemer: tx_context::sender(ctx),
      withdraw_asset: type_name::get<T>(),
      withdraw_amount: balance::value(&redeem_balance),
      burn_asset: type_name::get<MarketCoin<T>>(),
      burn_amount: market_coin_amount,
      time: now
    });
    coin::from_balance(redeem_balance, ctx)
  }
}
