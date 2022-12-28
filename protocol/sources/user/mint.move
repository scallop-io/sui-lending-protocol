module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::event::emit;
  use sui::transfer;
  use sui::balance;
  use time::timestamp::{Self ,TimeStamp};
  use protocol::bank::{Self, Bank};
  use protocol::bank_vault::BankCoin;
  
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
    timeOracle: &TimeStamp,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let depositAmount = coin::value(&coin);
    let now = timestamp::timestamp(timeOracle);
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
    
    transfer::transfer(coin::from_balance(mintBalance, ctx), sender);
  }
}
