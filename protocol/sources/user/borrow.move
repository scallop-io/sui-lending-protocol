module protocol::borrow {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::event::emit;
  use sui::balance::Balance;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, ID};
  use protocol::position::{Self, Position, PositionKey};
  use protocol::bank::{Self, Bank};
  use protocol::borrow_withdraw_evaluator;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::interest_model;
  
  const EBorrowTooMuch: u64 = 0;
  const EBorrowTooLittle: u64 = 0;
  
  struct BorrowEvent has copy, drop {
    borrower: address,
    position: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun borrow<T>(
    position: &mut Position,
    positionKey: &PositionKey,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    borrowAmount: u64,
    ctx: &mut TxContext,
  ) {
    let borrowedBalance = borrow_<T>(position, positionKey, bank, coinDecimalsRegistry, now, borrowAmount, ctx);
    // lend the coin to user
    transfer::transfer(
      coin::from_balance(borrowedBalance, ctx),
      tx_context::sender(ctx),
    );
  }
  
  public fun borrow_<T>(
    position: &mut Position,
    positionKey: &PositionKey,
    bank: &mut Bank,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    borrowAmount: u64,
    ctx: &mut TxContext,
  ): Balance<T> {
    position::assert_key_match(position, positionKey);
    
    let coinType = type_name::get<T>();
    let interestModel = bank::interest_model(bank, coinType);
    let minBorrowAmount = interest_model::min_borrow_amount(interestModel);
    assert!(borrowAmount > minBorrowAmount, EBorrowTooLittle);
    
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    let borrowedBalance = bank::handle_borrow<T>(bank, borrowAmount, now);
    
    // init debt if borrow for the first time
    position::init_debt(position, bank, coinType);
    // accure interests for position
    position::accrue_interests(position, bank);
    // calc the maximum borrow amount
    // If borrow too much, abort
    let maxBorrowAmount = borrow_withdraw_evaluator::max_borrow_amount<T>(position, bank, coinDecimalsRegistry);
    assert!(borrowAmount <= maxBorrowAmount, EBorrowTooMuch);
    // increase the debt for position
    position::increase_debt(position, coinType, borrowAmount);
    
    emit(BorrowEvent {
      borrower: tx_context::sender(ctx),
      position: object::id(position),
      asset: coinType,
      amount: borrowAmount,
      time: now,
    });
    borrowedBalance
  }
}
