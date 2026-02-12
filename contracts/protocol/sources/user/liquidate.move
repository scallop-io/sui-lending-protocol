/// @title Module for handling the liquidation request
/// @author Scallop Labs
/// @notice Scallop adopts soft liquidation. Liquidation amount should be no bigger than the amount that would drecrease the risk level of obligation to 1.
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
  use sui::math;
  use math::u64;

  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::liquidation_evaluator::{max_repay_amount, debt_to_collateral_amount};
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

  /// @notice Liquidate the obligation if possible, transfer the remainning base asset and liquidated collateral to the liquidator
  /// @dev This is a wrapper of `liquidate`, meant to be called by frontend.
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation to be liquidated
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param available_repay_coin The base asset used to repay the debt for the obligation
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param x_oracle The oracle object, used to get the price of the collateral and debt
  /// @param clock The SUI system clock object, used to get the current timestamp
  /// @param ctx The SUI transaction context object
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

    // Try to liquidate the obligation
    let (remain_coin, collateral_coin) = liquidate<DebtType, CollateralType>(version, obligation, market, available_repay_coin, coin_decimals_registry, x_oracle, clock, ctx);
    // Transfer the remaining base asset back to the sender
    transfer::public_transfer(remain_coin, tx_context::sender(ctx));
    // Transfer the liquiated collateral to the sender
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));
  }

  /// TODO: This is the old implementation, now I want to change the machanism like below:
  // Let’s say the user has collateral Ca worth 12.5$ with liquidation factor 0.8, and debt Da worth 6$, debt Db worth 3$ but with borrow weight of 2.
  //
  // So now, the total debt is 6 + 3 x 2 =12. the total collateral is 12.5 * 0.8 =10.
  // This means the user has bad debt of 12 - 10 =2 .
  //
  // Then liquidator comes, he can choose to repay 2$ worth Da or 1$ worth of Db to repay the bad debt.
  //
  // If liquidator repay 2$ worth of Da, I’ll give him 2 x 1.05 =2.1$ worth of Ca to compensate him.
  // If the liquidator repays 1$ worth of Db, I’ll give him 1.05$
  /// @notice Liquidate the obligation if possible, return the remaining base asset and liquidated collateral
  /// @dev It's best to call `liquidation_evaluator::max_liquidation_amounts` to get the max liquidable amount before calling this function
  /// @param version The version control object, contract version must match with this
  /// @param obligation The obligation to be liquidated
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param available_repay_coin The base asset used to repay the debt for the obligation
  /// @param coin_decimals_registry The registry object which contains the decimal information of coins
  /// @param x_oracle The oracle object, used to get the price of the collateral and debt
  /// @param clock The SUI system clock object, used to get the current timestamp
  /// @param ctx The SUI transaction context object
  /// @return the remaining base asset and liquidated collateral
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
    // Check the version
    version::assert_current_version(version);

    // check if sender is in whitelist
    market::assert_whitelist_access(market, ctx);

    // check if obligation is locked
    assert!(
      obligation::liquidate_locked(obligation) == false,
      error::obligation_locked()
    );

    let available_repay_balance = coin::into_balance(available_repay_coin);
    let now = clock::timestamp_ms(clock) / 1000;
    // Accrue interests for market
    market::accrue_all_interests(market, now);
    // Accrue interests & rewards for obligation
    obligation::accrue_interests(obligation, market);
    
    // Calculate max repay amount for this debt type (based on bad debt)
    let available_repay_amount = balance::value(&available_repay_balance);
    let max_repay = max_repay_amount<DebtType>(obligation, market, coin_decimals_registry, x_oracle, clock);
    let actual_repay = math::min(available_repay_amount, max_repay);
    assert!(actual_repay > 0, error::unable_to_liquidate_error());

    // Calculate collateral amounts: liquidator share (with bonus) and protocol share
    let (liq_amount, protocol_amount) = debt_to_collateral_amount<DebtType, CollateralType>(
      market, coin_decimals_registry, x_oracle, actual_repay, clock
    );

    // Cap by available collateral
    let collateral_type = type_name::get<CollateralType>();
    let total_collateral = obligation::collateral(obligation, collateral_type);
    let total_needed = liq_amount + protocol_amount;
    let (liq_amount, protocol_amount) = if (total_needed > total_collateral) {
      let scaled_liq = u64::mul_div(total_collateral, liq_amount, total_needed);
      let scaled_protocol = total_collateral - scaled_liq;
      (scaled_liq, scaled_protocol)
    } else {
      (liq_amount, protocol_amount)
    };
    assert!(liq_amount > 0, error::unable_to_liquidate_error());

    // Withdraw total collateral (liquidator + protocol share) from obligation
    let total_liq = liq_amount + protocol_amount;
    let collateral_balance = obligation::withdraw_collateral<CollateralType>(obligation, total_liq);

    // Reduce the debt - full repay amount goes to debt reduction
    let debt_type = type_name::get<DebtType>();
    obligation::decrease_debt(obligation, debt_type, actual_repay);
    market::handle_inflow<DebtType>(market, actual_repay, now);

    // Split collateral into liquidator and protocol portions
    let protocol_collateral_balance = balance::split(&mut collateral_balance, protocol_amount);
    // Split repay balance from available
    let repay_balance = balance::split(&mut available_repay_balance, actual_repay);
    // Handle market: debt repay goes to reserve, protocol collateral goes to revenue
    market::handle_liquidation_v2<DebtType, CollateralType>(market, repay_balance, protocol_collateral_balance, total_liq);

    emit(LiquidateEventV2 {
      liquidator: tx_context::sender(ctx),
      obligation: object::id(obligation),
      debt_type: type_name::get<DebtType>(),
      collateral_type: type_name::get<CollateralType>(),
      repay_on_behalf: actual_repay,
      repay_revenue: protocol_amount,
      liq_amount,
      collateral_price: price::get_price(x_oracle, type_name::get<CollateralType>(), clock),
      debt_price: price::get_price(x_oracle, type_name::get<DebtType>(), clock),
      timestamp: now,
    });

    // Send the remaining balance, and collateral balance to liquidator
    (
      coin::from_balance(available_repay_balance, ctx),
      coin::from_balance(collateral_balance, ctx)
    )
  }
}
