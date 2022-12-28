module protocol::redeem {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use time::timestamp::{Self ,TimeStamp};
  use protocol::bank::{Self, Bank};
  use protocol::bank_vault::BankCoin;
  
  struct RedeemEvent has copy, drop {
    redeemer: address,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
    burnAsset: TypeName,
    burnAmount: u64,
    time: u64,
  }
  
  public entry fun redeem<T>(
    bank: &mut Bank,
    timeOracle: &TimeStamp,
    coin: Coin<BankCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let bankCoinAmount = coin::value(&coin);
    let now = timestamp::timestamp(timeOracle);
    let redeemBalance = bank::handle_redeem(bank, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);
    emit(RedeemEvent {
      redeemer: tx_context::sender(ctx),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&redeemBalance),
      burnAsset: type_name::get<BankCoin<T>>(),
      burnAmount: bankCoinAmount,
      time: now
    });
    
    transfer::transfer(coin::from_balance(redeemBalance, ctx), sender);
  }
}
