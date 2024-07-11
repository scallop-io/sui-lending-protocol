/// @title Module for hanlding supply base asset request from user
/// @author Scallop Labs
/// @notice User get sCoin after supplying the base asset
module protocol::mint {
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::clock::{Self, Clock};
  use sui::event::emit;
  use sui::balance;
  use sui::dynamic_field as df;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::reserve::{Self, MarketCoin};
  use protocol::market_dynamic_keys::{Self, SupplyLimitKey};
  use sui::transfer;
  use whitelist::whitelist;
  use protocol::error;
  use x::wit_table;

  struct MintEvent has copy, drop {
    minter: address,
    deposit_asset: TypeName,
    deposit_amount: u64,
    mint_asset: TypeName,
    mint_amount: u64,
    time: u64,
  }

  /// @notice supply base asset and transfer the corresponding sCoin to sender
  /// @dev This is a wrapper for `mint`, meant to be called by frontend
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin The base asset to be supplied to the market
  /// @param clock The SUI system Clock object
  /// @ctx The SUI transaction context object
  /// @custom:T The type of asset to repay
  public entry fun mint_entry<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let mint_coin = mint(version, market, coin, clock, ctx);
    transfer::public_transfer(mint_coin, tx_context::sender(ctx));
  }

  /// @notice supply base asset and return the corresponding sCoin
  /// @dev The returned sCoin is an intrest bearing token, and is standard coin buth without CoinMetadata.
  ///      There's a limit for max total supply amount. Beyond this, trasanction will abort.
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param coin The base asset to be supplied to the market
  /// @param clock The SUI system Clock object
  /// @ctx The SUI transaction context object
  /// @custom:T The type of asset to repay
  /// @return sCoin that can be used to redeem for underlying base asset
  public fun mint<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    clock: &Clock,
    ctx: &mut TxContext,
  ): Coin<MarketCoin<T>> {
    // check if version is supported
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let coin_type = type_name::get<T>();
    // check if base asset is active
    assert!(
      market::is_base_asset_active(market, coin_type),
      error::base_asset_not_active_error()
    );

    let now = clock::timestamp_ms(clock) / 1000;
    let deposit_amount = coin::value(&coin);

    // Get the supply limit from the market
    let supply_limit_key = market_dynamic_keys::supply_limit_key(coin_type);
    let supply_limit = *df::borrow<SupplyLimitKey, u64>(market::uid(market), supply_limit_key);

    // Make sure the supply limit is not passed after supply
    let balance_sheets = reserve::balance_sheets(market::vault(market));
    let balance_sheet = wit_table::borrow(balance_sheets, coin_type);
    let (balance_sheet_cash, balance_sheet_debt, balance_sheet_revenue, _) = reserve::balance_sheet(balance_sheet);
    assert!(balance_sheet_cash + balance_sheet_debt - balance_sheet_revenue + deposit_amount <= supply_limit, error::supply_limit_reached());

    // Put the supplied asset into the market
    let mint_balance = market::handle_mint(market, coin::into_balance(coin), now);
    
    let sender = tx_context::sender(ctx);

    // Emit the mint event
    emit(MintEvent{
      minter: sender,
      deposit_asset: coin_type,
      deposit_amount,
      mint_asset: type_name::get<MarketCoin<T>>(),
      mint_amount: balance::value(&mint_balance),
      time: now,
    });

    // Return the sCoin
    coin::from_balance(mint_balance, ctx)
  }
}
