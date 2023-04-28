module protocol::withdraw_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::borrow_withdraw_evaluator;
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::coin::Coin;
  use oracle::switchboard_adaptor::SwitchboardBundle;

  const EWithdrawTooMuch: u64 = 0x80001;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    obligation: ID,
    withdraw_asset: TypeName,
    withdraw_amount: u64,
  }
  
  public entry fun withdraw_collateral_entry<T>(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let withdrawedCoin = withdraw_collateral<T>(
      obligation, obligation_key, market, coin_decimals_registry, withdraw_amount, switchboard_bundle, clock, ctx
    );
    transfer::public_transfer(withdrawedCoin, tx_context::sender(ctx));
  }
  
  public fun withdraw_collateral<T>(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    switchboard_bundle: &SwitchboardBundle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    let now = clock::timestamp_ms(clock);

    obligation::assert_key_match(obligation, obligation_key);
    // accrue interests for markets
    // Always update market state first
    // Because interest need to be accrued first before other operations
    market::handle_withdraw_collateral<T>(market, withdraw_amount, now);
  
    // accure interests for obligation
    obligation::accrue_interests(obligation, market);
    
    // IF withdraw_amount bigger than max, then abort
    let max_withdaw_amount = borrow_withdraw_evaluator::max_withdraw_amount<T>(obligation, market, coin_decimals_registry, switchboard_bundle);
    assert!(withdraw_amount <= max_withdaw_amount, EWithdrawTooMuch);
    
    // withdraw collateral from obligation
    let withdrawed_balance = obligation::withdraw_collateral<T>(obligation, withdraw_amount);
    
    let sender = tx_context::sender(ctx);
    emit(CollateralWithdrawEvent{
      taker: sender,
      obligation: object::id(obligation),
      withdraw_asset: type_name::get<T>(),
      withdraw_amount: balance::value(&withdrawed_balance),
    });
    coin::from_balance(withdrawed_balance, ctx)
  }
}
