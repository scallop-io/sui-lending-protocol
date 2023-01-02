module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::event::emit;
  use sui::transfer;
  use sui::balance;
  use protocol::bank::{Self, Bank};
  use protocol::bank_vault::BankCoin;
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
    bank: &mut Bank,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let mintBalance = mint_(bank, now, coin, ctx);
    transfer::transfer(coin::from_balance(mintBalance, ctx), tx_context::sender(ctx));
  }
  
  public fun mint_<T>(
    bank: &mut Bank,
    now: u64,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ): Balance<BankCoin<T>> {
    let depositAmount = coin::value(&coin);
    let mintBalance = bank::handle_mint(bank, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    
    emit(MintEvent{
      minter: sender,
      depositAsset: type_name::get<T>(),
      depositAmount,
      mintAsset: type_name::get<BankCoin<T>>(),
      mintAmount: balance::value(&mintBalance),
      time: now,
    });
    
    mintBalance
  }
}
