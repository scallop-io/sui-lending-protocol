module protocol::borrow {

  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::transfer;
  use sui::event::emit;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::borrow_withdraw_evaluator;
  use protocol::interest_model;
  use protocol::error;
  use x_oracle::x_oracle::XOracle;
  use whitelist::whitelist;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::balance;
  use protocol::market_dynamic_keys::{BorrowFeeKey, BorrowFeeRecipientKey};
  use sui::dynamic_field;

  use protocol::market_dynamic_keys;

  struct BorrowEvent has copy, drop {
    borrower: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun borrow_entry<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let borrowedCoin = borrow<T>(version, obligation, obligation_key, market, coin_decimals_registry, borrow_amount, x_oracle, clock, ctx);
    transfer::public_transfer(borrowedCoin, tx_context::sender(ctx));
  }
  
  public fun borrow<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    // check if version is supported
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    // check if obligation is locked
    assert!(
      obligation::borrow_locked(obligation) == false,
      error::obligation_locked()
    );

    let coin_type = type_name::get<T>();

    // check if base asset is active
    assert!(
      market::is_base_asset_active(market, coin_type),
      error::base_asset_not_active_error()
    );

    let now = clock::timestamp_ms(clock) / 1000;
    obligation::assert_key_match(obligation, obligation_key);
  
    let interest_model = market::interest_model(market, coin_type);
    let min_borrow_amount = interest_model::min_borrow_amount(interest_model);
    assert!(borrow_amount > min_borrow_amount, error::borrow_too_small_error());
    
    market::handle_outflow<T>(market, borrow_amount, now);

    // Always update market state first
    // Because interest need to be accrued first before other operations
    let borrowed_balance = market::handle_borrow<T>(market, borrow_amount, now);
    
    // init debt if borrow for the first time
    obligation::init_debt(obligation, market, coin_type);
    // accure interests & rewards for obligation
    obligation::accrue_interests_and_rewards(obligation, market);
    // calc the maximum borrow amount
    // If borrow too much, abort
    let max_borrow_amount = borrow_withdraw_evaluator::max_borrow_amount<T>(obligation, market, coin_decimals_registry, x_oracle, clock);
    assert!(borrow_amount <= max_borrow_amount, error::borrow_too_much_error());
    // increase the debt for obligation
    obligation::increase_debt(obligation, coin_type, borrow_amount);

    emit(BorrowEvent {
      borrower: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coin_type,
      amount: borrow_amount,
      time: now,
    });

    // Deduct borrow fee
    let borrow_fee_key = market_dynamic_keys::borrow_fee_key(type_name::get<T>());
    let borrow_fee_rate = dynamic_field::borrow<BorrowFeeKey, FixedPoint32>(market::uid(market), borrow_fee_key);
    let borrow_fee_amount = fixed_point32::multiply_u64(borrow_amount, *borrow_fee_rate);

    // Get the borrow fee recipient
    let borrow_fee_recipient_key = market_dynamic_keys::borrow_fee_recipient_key();
    let borrow_fee_recipient = dynamic_field::borrow<BorrowFeeRecipientKey, address>(market::uid(market), borrow_fee_recipient_key);

    // transfer the borrow fee to the recipient if borrow fee is not zero
    if (borrow_fee_amount > 0) {
      let borrow_fee = balance::split(&mut borrowed_balance, borrow_fee_amount);
      let borrow_fee_coin = coin::from_balance(borrow_fee, ctx);
      transfer::public_transfer(borrow_fee_coin, *borrow_fee_recipient);
    };

    coin::from_balance(borrowed_balance, ctx)
  }
}
