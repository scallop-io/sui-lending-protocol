module protocol::redeem {
  
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::transfer;
  use time::timestamp::{Self ,TimeStamp};
  use protocol::bank::{Self, Bank};
  use protocol::bank_vault::BankCoin;
  
  public entry fun redeem<T>(
    bank: &mut Bank,
    timeOracle: &TimeStamp,
    coin: Coin<BankCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let now = timestamp::timestamp(timeOracle);
    let redeemBalance = bank::handle_redeem(
      bank,
      coin::into_balance(coin),
      now
    );
    transfer::transfer(
      coin::from_balance(redeemBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
