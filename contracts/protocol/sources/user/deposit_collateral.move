/// @title A module dedicated for handling the collateral deposit request from user
/// @author Scallop Labs
module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use sui::dynamic_field as df;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use whitelist::whitelist;
  use protocol::error;
  use protocol::market_dynamic_keys::{Self, MinCollateralAmountKey};
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    obligation: ID,
    deposit_asset: TypeName,
    deposit_amount: u64,
  }

  /// @notice Deposit collateral into the given obligation
  /// @dev There's a overall collateral limit in the protocol configs, since market contains the configs, so market is also involved here
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation object to deposit collateral
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin The collateral to be deposited
  /// @param ctx The SUI transaction context object
  /// @custom:T The type of the collateral
  public entry fun deposit_collateral<T>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    // check version
    version::assert_current_version(version);
    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );
    // check if obligation is locked, if locked, unlock operation is required before calling this function
    // This is a mechanism to enforce some operations before calling the function
    assert!(
      obligation::deposit_collateral_locked(obligation) == false,
      error::obligation_locked()
    );

    let coin_type = type_name::get<T>();
    // check if collateral state is active
    assert!(
      market::is_collateral_active(market, coin_type),
      error::collateral_not_active_error()
    );

    // Make sure the protocol supports the collateral type
    let has_risk_model = market::has_risk_model(market, coin_type);
    assert!(has_risk_model == true, error::invalid_collateral_type_error());

    // Avoid the loop of collateralize and borrow of same assets
    assert!(!obligation::has_coin_x_as_debt(obligation, coin_type), error::unable_to_deposit_a_borrowed_coin());

    // Get the supply limit from the market
    let min_collateral_amount_key = market_dynamic_keys::min_collateral_amount_key(coin_type);
    let min_collateral_amount = *df::borrow<MinCollateralAmountKey, u64>(market::uid(market), min_collateral_amount_key);
    assert!(coin::value(&coin) >= min_collateral_amount, error::min_collateral_amount_error());

    // Emit collateral deposit event
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      obligation: object::id(obligation),
      deposit_asset: coin_type,
      deposit_amount: coin::value(&coin),
    });

    // Update the total collateral amount in the market
    market::handle_add_collateral<T>(market, coin::value(&coin));

    // Put the collateral into the obligation
    obligation::deposit_collateral(obligation, coin::into_balance(coin))
  }
}
