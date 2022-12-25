module protocol::withdraw_collateral {
  
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use time::timestamp::{Self ,TimeStamp};
  use protocol::position::{Self, Position};
  use protocol::evaluator;
  use protocol::bank::{Self, Bank};
  
  public entry fun withdraw_collateral<T>(
    position: &mut Position,
    bank: &mut Bank,
    timeOracle: &TimeStamp,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ) {
    // accrue interests for banks
    let now = timestamp::timestamp(timeOracle);
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    bank::compound_interests(bank, now);
  
    // accure interests for position
    position::accure_interests(position, bank);
    
    let maxWithdawAmount = evaluator::max_withdraw_amount<T>(position, bank);
    if (withdrawAmount > maxWithdawAmount) { return };
    
    // withdraw collateral from position, send it to user
    let withdrawedBalance = position::withdraw_collateral<T>(position, withdrawAmount);
    transfer::transfer(
      coin::from_balance(withdrawedBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
