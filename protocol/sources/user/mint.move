module protocol::mint {
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::transfer;
  use time::timestamp::{Self ,TimeStamp};
  use protocol::bank::{Self, Bank};
  
  public entry fun mint<T>(
    bank: &mut Bank,
    timeOracle: &TimeStamp,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = timestamp::timestamp(timeOracle);
    let mintBalance = bank::handle_mint(
      bank,
      coin::into_balance(coin),
      now
    );
    transfer::transfer(
      coin::from_balance(mintBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
