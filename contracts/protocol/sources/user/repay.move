module protocol::repay {

  use std::type_name::{Self, TypeName};
  use sui::event::emit;
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::math;
  use sui::transfer;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::error;
  use whitelist::whitelist;

  struct RepayEvent has copy, drop {
    repayer: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }
  
  public entry fun repay<T>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    user_coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // Check version
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let now = clock::timestamp_ms(clock) / 1000;
    let coin_type = type_name::get<T>();

    // always accrued all the interest before doing any actions
    market::accrue_all_interests(market, now);
    obligation::accrue_interests_and_rewards(obligation, market);

    let (debt_amount, _) = obligation::debt(obligation, coin_type);
    let repay_amount = math::min(debt_amount, coin::value(&user_coin));

    let repay_coin = coin::split<T>(&mut user_coin, repay_amount, ctx);
    // since handle_repay doesn't calling `accrue_all_interests`, we need to call it independently
    market::handle_repay<T>(market, coin::into_balance(repay_coin));
    market::handle_inflow<T>(market, repay_amount, now);

    // remove debt according to repay amount
    obligation::decrease_debt(obligation, coin_type, repay_amount);

    if (coin::value(&user_coin) == 0) {
      coin::destroy_zero(user_coin);
    } else {
      transfer::public_transfer(user_coin, tx_context::sender(ctx));
    };
    
    emit(RepayEvent {
      repayer: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coin_type,
      amount: repay_amount,
      time: now,
    })
  }
}
