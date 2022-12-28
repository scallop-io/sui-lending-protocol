module protocol::withdraw_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use time::timestamp::{Self ,TimeStamp};
  use protocol::position::{Self, Position};
  use protocol::evaluator;
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::event::emit;
  use sui::balance;
  
  const EWithdrawTooMuch: u64 = 0;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    position: ID,
    withdrawAsset: TypeName,
    withdrawAmount: u64,
  }
  
  public entry fun withdraw_collateral<T>(
    position: &mut Position,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
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
    
    // IF withdrawAmount bigger than max, then abort
    let maxWithdawAmount = evaluator::max_withdraw_amount<T>(position, bank, coinDecimalsRegistry);
    assert!(withdrawAmount <= maxWithdawAmount, EWithdrawTooMuch);
    
    // withdraw collateral from position
    let withdrawedBalance = position::withdraw_collateral<T>(position, withdrawAmount);
    
    let sender = tx_context::sender(ctx);
    emit(CollateralWithdrawEvent{
      taker: sender,
      position: object::id(position),
      withdrawAsset: type_name::get<T>(),
      withdrawAmount: balance::value(&withdrawedBalance),
    });
    
    transfer::transfer(coin::from_balance(withdrawedBalance, ctx), sender);
  }
}
