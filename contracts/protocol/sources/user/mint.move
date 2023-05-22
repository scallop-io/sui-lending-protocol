module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::event::emit;
  use sui::balance;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::reserve::MarketCoin;
  use sui::transfer;
  use whitelist::whitelist;
  use protocol::error;

  struct MintEvent has copy, drop {
    minter: address,
    deposit_asset: TypeName,
    deposit_amount: u64,
    mint_asset: TypeName,
    mint_amount: u64,
    time: u64,
  }
  
  public fun mint_entry<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let mint_coin = mint(version, market, coin, clock, ctx);
    transfer::public_transfer(mint_coin, tx_context::sender(ctx));
  }
  
  public fun mint<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<MarketCoin<T>> {
    // check if version is supported
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let now = clock::timestamp_ms(clock) / 1000;
    let deposit_amount = coin::value(&coin);
    let mint_balance = market::handle_mint(market, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    
    emit(MintEvent{
      minter: sender,
      deposit_asset: type_name::get<T>(),
      deposit_amount,
      mint_asset: type_name::get<MarketCoin<T>>(),
      mint_amount: balance::value(&mint_balance),
      time: now,
    });
    coin::from_balance(mint_balance, ctx)
  }
}
