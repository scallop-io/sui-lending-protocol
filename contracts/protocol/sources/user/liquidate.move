/// @title Liquidation module
/// @author Scallop Labs
/// @notice Handles soft liquidation of unhealthy obligations. The liquidator repays
///   a portion of the borrower's debt and receives discounted collateral in return.
///   The maximum repayable amount is capped so that liquidation brings the
///   obligation's risk level back toward 1 (not below).
module protocol::liquidate {

  use std::type_name::{Self, TypeName};
  use std::fixed_point32::FixedPoint32;
  use sui::clock::{Self, Clock};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::balance;
  use sui::transfer;
  use sui::event::emit;

  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::liquidation_evaluator::calculate_liquidation_amounts;
  use protocol::error;
  use protocol::price;
  use x_oracle::x_oracle::XOracle;
  use whitelist::whitelist;
  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;

  #[allow(unused_field)]
  struct LiquidateEvent has copy, drop {
    liquidator: address,
    obligation: ID,
    debt_type: TypeName,
    collateral_type: TypeName,
    repay_on_behalf: u64,
    repay_revenue: u64,
    liq_amount: u64,
  }

  struct LiquidateEventV2 has copy, drop {
    liquidator: address,
    obligation: ID,
    debt_type: TypeName,
    collateral_type: TypeName,
    repay_on_behalf: u64,
    repay_revenue: u64,
    liq_amount: u64,
    collateral_price: FixedPoint32,
    debt_price: FixedPoint32,
    timestamp: u64,
  }

  /// @notice Liquidate the obligation if possible, transfer the remaining base asset and liquidated collateral to the liquidator.
  /// @dev Convenience entry wrapper around `liquidate`.
  public entry fun liquidate_entry<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    available_repay_coin: Coin<DebtType>,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let (remain_coin, collateral_coin) = liquidate<DebtType, CollateralType>(
      version,
      obligation,
      market,
      available_repay_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );
    transfer::public_transfer(remain_coin, tx_context::sender(ctx));
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));
  }

  /// @notice Liquidate an unhealthy obligation: repay part of its debt and receive
  ///   discounted collateral in return.
  /// @dev To preview liquidation amounts before calling this function:
  ///   1. Call `accrue_interest::accrue_interest_for_market_and_obligation(...)` to bring
  ///      interest state up to date.
  ///   2. Call `liquidation_evaluator::calculate_liquidation_amounts<DebtType, CollateralType>(...)`
  ///      to get `(actual_repay, liq_amount, protocol_amount)`.
  /// @return (remaining_repay_coin, collateral_coin) — leftover input coin and the
  ///   collateral awarded to the liquidator.
  public fun liquidate<DebtType, CollateralType>(
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
    market::assert_whitelist_access(market, ctx);
    assert!(
      obligation::liquidate_locked(obligation) == false,
      error::obligation_locked()
    );

    // --- 2. Prepare state ---
    let available_repay_balance = coin::into_balance(available_repay_coin);
    let now = clock::timestamp_ms(clock) / 1000;
    market::accrue_all_interests(market, now);
    obligation::accrue_interests(obligation, market);

    // Cache type names — used in both calculation and event emission
    let debt_type = type_name::get<DebtType>();
    let collateral_type = type_name::get<CollateralType>();

    // --- 3. Calculate liquidation amounts ---
    let available_repay_amount = balance::value(&available_repay_balance);
    let (actual_repay, liq_amount, protocol_amount) = calculate_liquidation_amounts<DebtType, CollateralType>(
      obligation, market, coin_decimals_registry, x_oracle, clock,
      available_repay_amount, collateral_type,
    );

    // --- 4. Execute liquidation ---
    // Withdraw total collateral (liquidator + protocol share) from obligation
    let total_liq = liq_amount + protocol_amount;
    let collateral_balance = obligation::withdraw_collateral<CollateralType>(obligation, total_liq);

    // Reduce the debt
    obligation::decrease_debt(obligation, debt_type, actual_repay);
    market::handle_inflow<DebtType>(market, actual_repay, now);

    // Split collateral into liquidator and protocol portions
    let protocol_collateral_balance = balance::split(&mut collateral_balance, protocol_amount);
    let repay_balance = balance::split(&mut available_repay_balance, actual_repay);
    market::handle_liquidation_v2<DebtType, CollateralType>(market, repay_balance, protocol_collateral_balance, total_liq);

    // --- 5. Emit event ---
    // Cache prices once for the event
    let collateral_price = price::get_price(x_oracle, collateral_type, clock);
    let debt_price = price::get_price(x_oracle, debt_type, clock);
    emit(LiquidateEventV2 {
      liquidator: tx_context::sender(ctx),
      obligation: object::id(obligation),
      debt_type,
      collateral_type,
      repay_on_behalf: actual_repay,
      repay_revenue: protocol_amount,
      liq_amount,
      collateral_price,
      debt_price,
      timestamp: now,
    });

    // --- 6. Return remaining coin + collateral to liquidator ---
    (
      coin::from_balance(available_repay_balance, ctx),
      coin::from_balance(collateral_balance, ctx)
    )
  }

}
