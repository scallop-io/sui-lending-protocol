/// @title Module for hanlding withdraw collateral request from user
/// @author Scallop Labs
/// @notice User can withdarw collateral as long as the obligation risk level is lower than 1
module protocol::withdraw_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::transfer;
  use sui::event::emit;
  use sui::balance;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::borrow_withdraw_evaluator;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::error;
  use x_oracle::x_oracle::XOracle;
  use whitelist::whitelist;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  
  struct CollateralWithdrawEvent has copy, drop {
    taker: address,
    obligation: ID,
    withdraw_asset: TypeName,
    withdraw_amount: u64,
  }


  /// @notice Withdraw collateral from obligation, and transfer it to the sender
  /// @dev This function is not composable, it's a wrapper of withdraw_collateral
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation from which to withdraw collateral
  /// @param obligation_key The key to prove the ownership of the obligation
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param withdarw_amount The collateral amount to withdraw
  /// @param x_oracle The x-oracle object which provides the price of assets
  /// @param clock The SUI system clock object
  /// @param ctx The SUI transaction context object
  /// @custom:T The type of the collateral to withdraw
  public entry fun withdraw_collateral_entry<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let withdrawedCoin = withdraw_collateral<T>(
      version, obligation, obligation_key, market, coin_decimals_registry, withdraw_amount, x_oracle, clock, ctx
    );
    transfer::public_transfer(withdrawedCoin, tx_context::sender(ctx));
  }

  /// @notice Withdraw collateral from obligation, and return the collateral
  /// @dev Cannot withdraw more than the amount which could make the obligation risk level higher than 1,
  ///  can call the borrow_withdraw_evaluator::max_withdraw_amount to get the max withdraw amount
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation from which to withdraw collateral
  /// @param obligation_key The key to prove the ownership of the obligation
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param withdarw_amount The collateral amount to withdraw
  /// @param x_oracle The x-oracle object which provides the price of assets
  /// @param clock The SUI system clock object
  /// @param ctx The SUI transaction context object
  /// @custom:T The type of the collateral to withdraw
  /// @return The collateral that has been withdrawn
  public fun withdraw_collateral<T>(
    version: &Version,
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    withdraw_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<T> {
    // check version
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    // check if obligation is locked, if locked, unlock is required before calling this
    // This is a mechanism to enforce some actions before withdraw collateral
    assert!(
      obligation::withdraw_collateral_locked(obligation) == false,
      error::obligation_locked()
    );

    let now = clock::timestamp_ms(clock) / 1000;

    // Check the ownership of the obligation
    obligation::assert_key_match(obligation, obligation_key);

    // accrue interests for markets
    // Always update market state first
    // Because interest need to be accrued first to reflect the latest state
    market::handle_withdraw_collateral<T>(market, withdraw_amount, now);
  
    // accure interests & rewards for obligation
    obligation::accrue_interests_and_rewards(obligation, market);
    
    // If withdraw_amount bigger than max allowed withdraw amount, abort
    // Max withdarw amount is calculated according to the risk level of the obligation, if risk level is higher than 1, withdraw is not allowed
    let max_withdaw_amount = borrow_withdraw_evaluator::max_withdraw_amount<T>(obligation, market, coin_decimals_registry, x_oracle, clock);
    assert!(withdraw_amount <= max_withdaw_amount, error::withdraw_collateral_too_much_error());
    
    // withdraw collateral from obligation
    let withdrawed_balance = obligation::withdraw_collateral<T>(obligation, withdraw_amount);

    // Emit the collateral withdraw event
    let sender = tx_context::sender(ctx);
    emit(CollateralWithdrawEvent{
      taker: sender,
      obligation: object::id(obligation),
      withdraw_asset: type_name::get<T>(),
      withdraw_amount: balance::value(&withdrawed_balance),
    });

    // Return the withdrawn collateral
    coin::from_balance(withdrawed_balance, ctx)
  }
}
