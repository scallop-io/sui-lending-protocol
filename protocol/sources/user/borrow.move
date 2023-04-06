module protocol::borrow {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::event::emit;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::market::{Self, Market};
  use protocol::borrow_withdraw_evaluator;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use protocol::interest_model;
  use sui::coin::Coin;

  const EBorrowTooMuch: u64 = 0;
  const EBorrowTooLittle: u64 = 0;
  
  struct BorrowEvent has copy, drop {
    borrower: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun borrow_entry<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    borrowAmount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let borrowedCoin = borrow<T>(obligation, obligationKey, market, coinDecimalsRegistry, borrowAmount, clock, ctx);
    transfer::public_transfer(borrowedCoin, tx_context::sender(ctx));
  }
  
  public fun borrow<T>(
    obligation: &mut Obligation,
    obligationKey: &ObligationKey,
    market: &mut Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    borrowAmount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    let now = clock::timestamp_ms(clock);
    obligation::assert_key_match(obligation, obligationKey);
  
    let coinType = type_name::get<T>();
    let interestModel = market::interest_model(market, coinType);
    let minBorrowAmount = interest_model::min_borrow_amount(interestModel);
    assert!(borrowAmount > minBorrowAmount, EBorrowTooLittle);
    
    // Always update market state first
    // Because interest need to be accrued first before other operations
    let borrowedBalance = market::handle_borrow<T>(market, borrowAmount, now);
    
    // init debt if borrow for the first time
    obligation::init_debt(obligation, market, coinType);
    // accure interests for obligation
    obligation::accrue_interests(obligation, market);
    // calc the maximum borrow amount
    // If borrow too much, abort
    let maxBorrowAmount = borrow_withdraw_evaluator::max_borrow_amount<T>(obligation, market, coinDecimalsRegistry);
    assert!(borrowAmount <= maxBorrowAmount, EBorrowTooMuch);
    // increase the debt for obligation
    obligation::increase_debt(obligation, coinType, borrowAmount);
    
    emit(BorrowEvent {
      borrower: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coinType,
      amount: borrowAmount,
      time: now,
    });
    coin::from_balance(borrowedBalance, ctx)
  }
}
