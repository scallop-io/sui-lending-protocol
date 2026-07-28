/// @title Forced deleverage evaluator
/// @author Scallop Labs
/// @notice Amount calculation for `protocol::forced_deleverage`: converts a repay
///   amount into the collateral amount of exactly equal USD value.
///   Depends only on oracle prices and coin decimals — no RiskModel, no Market.
module protocol::forced_deleverage_evaluator {

  use std::type_name;
  use std::fixed_point32;
  use sui::math;
  use sui::clock::Clock;

  use protocol::obligation::{Self, Obligation};
  use protocol::error;
  use protocol::price::get_price;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  /// @notice Compute `(actual_repay, seized_amount)` for a forced deleverage at 1:1 USD value.
  /// @dev To preview amounts before calling `forced_deleverage`, first bring interest
  ///   up to date via `accrue_interest::accrue_interest_for_market_and_obligation(...)`,
  ///   then call this function.
  ///
  ///   actual_repay = min(available_repay_amount, outstanding DebtType debt)
  ///   seized       = floor(actual_repay * raw_d * s_c / (raw_c * s_d))
  ///
  ///   If `seized` exceeds the obligation's CollateralType balance, all collateral is
  ///   seized and the repay is scaled down by the same proportional floor liquidation
  ///   uses (`liquidation_evaluator::calculate_liquidation_amounts`).
  public fun calculate_forced_deleverage_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    available_repay_amount: u64,
  ): (u64, u64) {
    let debt_type = type_name::get<DebtType>();
    let collateral_type = type_name::get<CollateralType>();

    // Zero-amount rows are deleted from the wit-tables, so `debt` / `collateral`
    // abort on missing keys; guard with clear errors first.
    assert!(
      obligation::has_coin_x_as_debt(obligation, debt_type),
      error::forced_deleverage_no_debt_error()
    );
    assert!(
      obligation::has_coin_x_as_collateral(obligation, collateral_type),
      error::forced_deleverage_no_collateral_error()
    );

    // Cap repay at the outstanding debt; the caller refunds the leftover coin.
    let (debt_amount, _) = obligation::debt(obligation, debt_type);
    let actual_repay = math::min(available_repay_amount, debt_amount);

    // Prices abort unless updated in this same second (price::get_price).
    let debt_price_raw = fixed_point32::get_raw_value(get_price(x_oracle, debt_type, clock));
    let collateral_price_raw = fixed_point32::get_raw_value(get_price(x_oracle, collateral_type, clock));
    let debt_scale = math::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, debt_type));
    let collateral_scale = math::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, collateral_type));

    // seized = repay * raw_d * s_c / (raw_c * s_d) — the 2^32 factors of the two
    // FixedPoint32 raws cancel. Evaluated in u256: the triple product cannot
    // overflow and the single division is the only rounding step, floored in
    // the user's favor.
    let seized_needed =
      (actual_repay as u256) * (debt_price_raw as u256) * (collateral_scale as u256)
        / ((collateral_price_raw as u256) * (debt_scale as u256));

    // Collateral-short path: seize everything and scale the repay down with the
    // same proportional floor as liquidation. `seized_needed` stays u256 until
    // after this cap, so no overflowing u64 cast is reachable on any input.
    let total_collateral = obligation::collateral(obligation, collateral_type);
    let (actual_repay, seized_amount) = if (seized_needed > (total_collateral as u256)) {
      let scaled_repay = (actual_repay as u256) * (total_collateral as u256) / seized_needed;
      ((scaled_repay as u64), total_collateral)
    } else {
      (actual_repay, (seized_needed as u64))
    };

    assert!(actual_repay > 0, error::unable_to_force_deleverage_error());
    assert!(seized_amount > 0, error::unable_to_force_deleverage_error());

    (actual_repay, seized_amount)
  }
}
