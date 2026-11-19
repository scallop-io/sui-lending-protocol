/// Moves reserve and obligation balances into their dynamic-field storage.
///
/// - `migrate_underlying_balance` is run by the admin for each coin type in the reserve.
/// - `migrate_collateral_balance` is run for each coin type held by an obligation, by an
///   address in the balance migration authority registry on the market.
///
/// Both only move a balance between two stores inside the same object, so accounting
/// (balance sheets, collateral records, debts) is unchanged. Calling either again for a
/// coin type that was already moved moves nothing.
module protocol::balance_migration {
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, ID};
  use sui::tx_context::{Self, TxContext};
  use sui::event;
  use sui::dynamic_field as df;
  use sui::vec_set::{Self, VecSet};
  use protocol::app::AdminCap;
  use protocol::market::{Self, Market};
  use protocol::market_dynamic_keys::{Self, BalanceMigrationAuthorityRegistryKey};
  use protocol::obligation::{Self, Obligation};
  use protocol::version::{Self, Version};
  use protocol::error;

  struct UnderlyingBalanceMigratedEvent has copy, drop {
    market: ID,
    coin_type: TypeName,
    amount: u64,
  }

  struct CollateralBalanceMigratedEvent has copy, drop {
    obligation: ID,
    coin_type: TypeName,
    amount: u64,
    executor: address,
  }

  /// Move the reserve's underlying balance of coin `T` into its dynamic-field storage.
  public fun migrate_underlying_balance<T>(
    _admin_cap: &AdminCap,
    version: &Version,
    market: &mut Market,
    ctx: &mut TxContext,
  ) {
    version::assert_current_version(version);

    let amount = market::migrate_underlying_balance<T>(market, ctx);

    event::emit(UnderlyingBalanceMigratedEvent {
      market: object::id(market),
      coin_type: type_name::get<T>(),
      amount,
    });
  }

  /// Move the obligation's collateral balance of coin `T` into its dynamic-field storage.
  public fun migrate_collateral_balance<T>(
    version: &Version,
    market: &Market,
    obligation: &mut Obligation,
    ctx: &mut TxContext,
  ) {
    version::assert_current_version(version);
    assert_balance_migration_authority(market, ctx);

    let amount = obligation::migrate_collateral_balance<T>(obligation, ctx);

    event::emit(CollateralBalanceMigratedEvent {
      obligation: object::id(obligation),
      coin_type: type_name::get<T>(),
      amount,
      executor: tx_context::sender(ctx),
    });
  }

  fun assert_balance_migration_authority(market: &Market, ctx: &TxContext) {
    let key = market_dynamic_keys::balance_migration_authority_registry_key();
    let market_uid = market::uid(market);
    assert!(
      df::exists_<BalanceMigrationAuthorityRegistryKey>(market_uid, key),
      error::unauthorized_balance_migration_error()
    );
    let registry = df::borrow<BalanceMigrationAuthorityRegistryKey, VecSet<address>>(market_uid, key);
    assert!(
      vec_set::contains(registry, &tx_context::sender(ctx)),
      error::unauthorized_balance_migration_error()
    );
  }
}
