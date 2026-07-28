/// @title Forced deleverage module
/// @author Scallop Labs
/// @notice Used to wind down deprecated assets. An authorized executor repays a user's
///   debt and receives collateral of exactly equal USD value in return — no liquidation
///   discount, no protocol revenue cut, no health-factor requirement.
///   Guardrail: tx sender must be in the ForcedDeleverageAuthorityRegistry on Market.
module protocol::forced_deleverage {

  use std::type_name::{Self, TypeName};
  use std::fixed_point32::FixedPoint32;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::balance;
  use sui::transfer;
  use sui::event::emit;
  use sui::dynamic_field as df;
  use sui::vec_set::{Self, VecSet};

  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::market_dynamic_keys::{Self, ForcedDeleverageAuthorityRegistryKey};
  use protocol::error;
  use protocol::price;
  use protocol::forced_deleverage_evaluator::calculate_forced_deleverage_amounts;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;

  struct ForcedDeleverageEvent has copy, drop {
    executor: address,
    obligation: ID,
    debt_type: TypeName,
    collateral_type: TypeName,
    repay_amount: u64,
    seized_amount: u64,
    debt_price: FixedPoint32,
    collateral_price: FixedPoint32,
    timestamp: u64,
  }

  /// @notice Entry wrapper: transfers leftover repay coin and seized collateral to the sender.
  public entry fun forced_deleverage_entry<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let (remain_coin, collateral_coin) = forced_deleverage<DebtType, CollateralType>(
      version, obligation, market, available_repay_coin,
      coin_decimals_registry, x_oracle, clock, ctx
    );
    transfer::public_transfer(remain_coin, tx_context::sender(ctx));
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));
  }

  /// @notice Repay `DebtType` debt on the obligation and seize `CollateralType` collateral
  ///   of exactly equal USD value.
  /// @dev To preview amounts before calling this function:
  ///   1. Call `accrue_interest::accrue_interest_for_market_and_obligation(...)` to bring
  ///      interest state up to date.
  ///   2. Call `forced_deleverage_evaluator::calculate_forced_deleverage_amounts<DebtType, CollateralType>(...)`
  ///      to get `(actual_repay, seized_amount)`.
  /// @return (remaining_repay_coin, seized_collateral_coin)
  public fun forced_deleverage<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<DebtType>, Coin<CollateralType>) {

    // --- 1. Validate preconditions ---
    version::assert_current_version(version);

    // Dedicated ACL: only addresses in the ForcedDeleverageAuthorityRegistry on Market can call this function
    assert_forced_deleverage_authority(market, ctx);

    let debt_type = type_name::get<DebtType>();
    let collateral_type = type_name::get<CollateralType>();

    assert!(debt_type != collateral_type, error::unable_to_force_deleverage_error());

    // because it's similar to liquidation mechanism
    assert!(
      obligation::liquidate_locked(obligation) == false,
      error::obligation_locked()
    );

    assert!(coin::value(&available_repay_coin) > 0, error::unable_to_force_deleverage_error());

    // --- 2. Prepare state ---
    let available_repay_balance = coin::into_balance(available_repay_coin);
    let now = clock::timestamp_ms(clock) / 1000;
    market::accrue_all_interests(market, now);
    obligation::accrue_interests(obligation, market);

    // --- 3. Amounts at exact 1:1 USD value ---
    // Row guards, the debt cap, the par conversion, and the collateral cap all
    // live in the evaluator. Prices abort unless updated in this same second,
    // so the PTB must bundle x-oracle updates for both types.
    let (actual_repay, seized_amount) = calculate_forced_deleverage_amounts<DebtType, CollateralType>(
      obligation, coin_decimals_registry, x_oracle, clock,
      balance::value(&available_repay_balance),
    );

    // --- 4. Mutate obligation, then market (same order as liquidate.move) ---
    let collateral_balance = obligation::withdraw_collateral<CollateralType>(obligation, seized_amount);
    obligation::decrease_debt(obligation, debt_type, actual_repay);

    let repay_balance = balance::split(&mut available_repay_balance, actual_repay);
    market::handle_repay<DebtType>(market, repay_balance, now);
    market::handle_inflow<DebtType>(market, actual_repay, now);
    market::handle_withdraw_collateral<CollateralType>(market, seized_amount, now);

    // --- 5. Emit event ---
    // Cache prices once for the event; same-second freshness was already proven
    // by the evaluator's get_price calls.
    let debt_price = price::get_price(x_oracle, debt_type, clock);
    let collateral_price = price::get_price(x_oracle, collateral_type, clock);
    emit(ForcedDeleverageEvent {
      executor: tx_context::sender(ctx),
      obligation: object::id(obligation),
      debt_type,
      collateral_type,
      repay_amount: actual_repay,
      seized_amount,
      debt_price,
      collateral_price,
      timestamp: now,
    });

    // --- 6. Return leftover repay coin + seized collateral to the executor ---
    (
      coin::from_balance(available_repay_balance, ctx),
      coin::from_balance(collateral_balance, ctx)
    )
  }

  fun assert_forced_deleverage_authority(market: &Market, ctx: &TxContext) {
    let key = market_dynamic_keys::forced_deleverage_authority_registry_key();
    let market_uid = market::uid(market);
    assert!(
      df::exists_<ForcedDeleverageAuthorityRegistryKey>(market_uid, key),
      error::unauthorized_forced_deleverage_error()
    );
    let registry = df::borrow<ForcedDeleverageAuthorityRegistryKey, VecSet<address>>(market_uid, key);
    assert!(
      vec_set::contains(registry, &tx_context::sender(ctx)),
      error::unauthorized_forced_deleverage_error()
    );
  }
}
