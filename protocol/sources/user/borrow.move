module protocol::borrow {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
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
  use oracle::switchboard_adaptor::SwitchboardBundle;
  use whitelist::whitelist;

  const EBorrowTooMuch: u64 = 0x10001;
  const EBorrowTooLittle: u64 = 0x10002;
  
  struct BorrowEvent has copy, drop {
    borrower: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun borrow_entry<T>(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let borrowedCoin = borrow<T>(obligation, obligation_key, market, coin_decimals_registry, borrow_amount, switchboard_bundle, clock, ctx);
    transfer::public_transfer(borrowedCoin, tx_context::sender(ctx));
  }
  
  public fun borrow<T>(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    // check if sender is in whitelist
    whitelist::in_whitelist(market::uid(market), tx_context::sender(ctx));

    let now = clock::timestamp_ms(clock);
    obligation::assert_key_match(obligation, obligation_key);
  
    let coin_type = type_name::get<T>();
    let interest_model = market::interest_model(market, coin_type);
    let min_borrow_amount = interest_model::min_borrow_amount(interest_model);
    assert!(borrow_amount > min_borrow_amount, EBorrowTooLittle);
    
    market::handle_outflow<T>(market, borrow_amount, now);

    // Always update market state first
    // Because interest need to be accrued first before other operations
    let borrowed_balance = market::handle_borrow<T>(market, borrow_amount, now);
    
    // init debt if borrow for the first time
    obligation::init_debt(obligation, market, coin_type);
    // accure interests for obligation
    obligation::accrue_interests(obligation, market);
    // calc the maximum borrow amount
    // If borrow too much, abort
    let max_borrow_amount = borrow_withdraw_evaluator::max_borrow_amount<T>(obligation, market, coin_decimals_registry, switchboard_bundle);
    assert!(borrow_amount <= max_borrow_amount, EBorrowTooMuch);
    // increase the debt for obligation
    obligation::increase_debt(obligation, coin_type, borrow_amount);
    
    emit(BorrowEvent {
      borrower: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coin_type,
      amount: borrow_amount,
      time: now,
    });
    coin::from_balance(borrowed_balance, ctx)
  }
}
