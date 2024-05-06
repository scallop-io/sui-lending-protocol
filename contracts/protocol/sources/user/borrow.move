/// @title A module dedicated for handling the borrow request from user
/// @author Scallop Labs
module protocol::borrow {

  use std::fixed_point32::{Self, FixedPoint32};
  use std::type_name::{Self, TypeName};
  use std::option::{Self, Option};
  use sui::coin::{Self, Coin};
  use sui::transfer;
  use sui::event::emit;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, ID};
  use sui::clock::{Self, Clock};
  use sui::balance::{Self, Balance};
  use sui::dynamic_field;

  use protocol::obligation::{Self, Obligation, ObligationKey};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::borrow_withdraw_evaluator;
  use protocol::interest_model;
  use protocol::error;
  use protocol::market_dynamic_keys::{Self, BorrowFeeKey, BorrowFeeRecipientKey};

  use x_oracle::x_oracle::XOracle;
  use whitelist::whitelist;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;


  #[allow(unused_field)]
  struct BorrowEvent has copy, drop {
    borrower: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    time: u64,
  }

  struct BorrowEventV2 has copy, drop {
    borrower: address,
    obligation: ID,
    asset: TypeName,
    amount: u64,
    borrow_fee: u64,
    time: u64,
  }


  /// @notice Borrow a certain amount of asset from the protocol and transfer it to the sender
  /// @dev This function is not composable, and is intended to be called by the frontend
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation object which contains the collateral and debt information
  /// @param obligation_key The key to prove the ownership the obligation object
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param borrow_amount The amount of asset to borrow
  /// @param x_oracle The x-oracle object which provides the price of assets
  /// @param clock The SUI system Clock object, 0x6
  /// @param ctx The SUI transaction context object
  /// @custom:T The type of the asset to borrow, such as 0x2::sui::SUI for SUI
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
    let borrowed_coin = borrow<T>(version, obligation, obligation_key, market, coin_decimals_registry, borrow_amount, x_oracle, clock, ctx);
    transfer::public_transfer(borrowed_coin, tx_context::sender(ctx));
  }

  /// @notice Borrow a certain amount of asset from the protocol
  /// @dev This function is composable, third party contract call this method to borrow from Scallop
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation object which contains the collateral and debt information
  /// @param obligation_key The key to prove the ownership the obligation object
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param borrow_amount The amount of asset to borrow
  /// @param x_oracle The x-oracle object which provides the price of assets
  /// @param clock The SUI system Clock object, 0x6
  /// @param ctx The SUI transaction context object
  /// @custom:T The type of the asset to borrow, such as 0x2::sui::SUI for SUI
  /// @return borrowed assets
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

    let borrowed_balance = borrow_internal<T>(
      obligation, 
      obligation_key, 
      market, 
      coin_decimals_registry, 
      borrow_amount, 
      x_oracle,
      clock, 
      ctx
    );

    coin::from_balance(borrowed_balance, ctx)
  }

  fun borrow_internal<T>(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    borrow_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Balance<T> {
    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    // check if obligation is locked, if locked, unlock operation is required before calling this function
    // This is a mechanism to enforce some operations before calling the function
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

    // Check the ownership of the obligation
    obligation::assert_key_match(obligation, obligation_key);

    // Avoid the loop of collateralize and borrow of same assets
    assert!(!obligation::has_coin_x_as_collateral(obligation, coin_type), error::unable_to_borrow_a_collateral_coin());

    // Make sure the borrow amount is bigger than the minimum borrow amount
    let interest_model = market::interest_model(market, coin_type);
    let min_borrow_amount = interest_model::min_borrow_amount(interest_model);
    assert!(borrow_amount > min_borrow_amount, error::borrow_too_small_error());

    // Add borrow amount to the outflow limiter, if limit is reached then abort
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

    // Calculate the base borrow fee
    let base_borrow_fee_key = market_dynamic_keys::borrow_fee_key(type_name::get<T>());
    let base_borrow_fee_rate = dynamic_field::borrow<BorrowFeeKey, FixedPoint32>(market::uid(market), base_borrow_fee_key);
    let base_borrow_fee_amount = fixed_point32::multiply_u64(borrow_amount, *base_borrow_fee_rate);

    // transfer the borrow fee to the fee collector address if borrow fee is not zero
    if (base_borrow_fee_amount > 0) {
      // Get the borrow fee collector address
      let borrow_fee_recipient_key = market_dynamic_keys::borrow_fee_recipient_key();
      let borrow_fee_recipient = dynamic_field::borrow<BorrowFeeRecipientKey, address>(market::uid(market), borrow_fee_recipient_key);

      // Split the borrow fee from borrowed asset
      let borrow_fee = balance::split(&mut borrowed_balance, base_borrow_fee_amount);
      let borrow_fee_coin = coin::from_balance(borrow_fee, ctx);

      // transfer fee to the collector address
      transfer::public_transfer(borrow_fee_coin, *borrow_fee_recipient);
    };

    // Emit the borrow event
    emit(BorrowEvent {
      borrower: tx_context::sender(ctx),
      obligation: object::id(obligation),
      asset: coin_type,
      amount: borrow_amount,
      time: now,
    });

    // Return the borrowed asset
    borrowed_balance
  }
}
