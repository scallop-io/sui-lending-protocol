module protocol::liquidation_evaluator {
  use std::type_name;
  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use sui::math;
  use sui::clock::Clock;
  use math::fixed_point32_empower;
  use math::u64;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::debt_value::{debts_value_usd_with_weight, debts_value_usd};
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::risk_model;
  use protocol::error;
  use protocol::price::get_price;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  /// Each liquidation call may repay at most 1/LIQUIDATION_CAP_DIVISOR (20%) of the
  /// obligation's total outstanding debt value, preventing incremental over-liquidation.
  const LIQUIDATION_CAP_DIVISOR: u64 = 5;

  /// Obligations whose total debt value (in USD) is at or below this threshold are
  /// considered dust positions. A full repay is allowed in one call so that these
  /// tiny positions can be cleared without the gas cost exceeding the liquidation incentive.
  const LIQUIDATION_DUST_THRESHOLD_USD: u64 = 10;

  // @deprecated
  // calculate the actual repay amount, actual liquidate amount, actual market amount
  public fun liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    available_repay_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
  ): (u64, u64, u64) {
    abort 0
  }

  // @deprecated
  // calculate the maximum repay amount, max liquidate amount
  public fun max_liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): (u64, u64) {
    abort 0
  }

  /// Calculates the maximum amount of `DebtType` tokens a liquidator can repay
  /// for an unhealthy obligation.
  ///
  /// An obligation is liquidatable when its weighted debt value exceeds its
  /// collateral value (adjusted for liquidation thresholds):
  ///   weighted_debts_value > collaterals_value
  ///
  /// To prevent a single liquidation from stripping so much collateral that it
  /// creates fresh bad debt on the same obligation, the per-call repayment is
  /// capped at 20% of the **total outstanding debt value across all types**,
  /// converted back to `DebtType` token units:
  ///   max_repay_usd    = 20% * total_debts_value_usd   (sum of all debt types)
  ///   max_repay_amount = max_repay_usd / debt_price * debt_scale
  ///                      (capped at the actual debt balance of DebtType)
  ///
  /// Exception — dust positions: when the total USD value of all debts on the
  /// obligation falls below $10, a full repay is allowed so that tiny positions
  /// can be cleared in one call (gas cost would otherwise exceed any partial-
  /// liquidation incentive).
  ///
  /// Returns 0 if the obligation is healthy (not liquidatable).
  ///
  /// Example 1 — single debt: 850 USDC at $1:
  ///   total_debts_value_usd = $850 > $10 → apply 20% cap
  ///   max_repay_usd    = 20% * $850 = $170
  ///   max_repay_amount = $170 / $1  = 170 USDC = 170_000_000_000
  ///
  /// Example 2 — two debts: Da = 500 USDC at $1, Db = 200 ETH at $3:
  ///   total_debts_value_usd = $500 + $600 = $1,100 > $10 → apply 20% cap
  ///   max_repay_usd    = 20% * $1,100 = $220
  ///   max_repay_Da     = $220 / $1 = 220 USDC  (≤ 500 USDC balance → 220 USDC)
  ///   max_repay_Db     = $220 / $3 ≈ 73 ETH    (≤ 200 ETH balance → ~73 ETH)
  ///
  /// Example 3 — dust position: 5 USDC total debt at $1:
  ///   total_debts_value_usd = $5 < $10 → full repay allowed
  ///   max_repay_amount = 5_000_000_000 (5 USDC)
  public fun max_repay_amount<DebtType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let debt_type = type_name::get<DebtType>();

    // Compute portfolio values: collateral (liquidation-adjusted) vs weighted debts
    let collaterals_value = collaterals_value_usd_for_liquidation(obligation, market, coin_decimals_registry, x_oracle, clock);
    let weighted_debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);

    // Obligation is healthy — not eligible for liquidation
    if (!fixed_point32_empower::gt(weighted_debts_value, collaterals_value)) {
      return 0
    };

    // Get total outstanding debt of this type
    let (total_debt_amount, _) = obligation::debt(obligation, debt_type);

    // Total USD value across all debt types
    let total_debts_value = debts_value_usd(obligation, coin_decimals_registry, x_oracle, clock);

    // Dust position: when total debt value across all types is below LIQUIDATION_DUST_THRESHOLD_USD, allow
    // a full repay so tiny positions can be fully cleared in a single call.
    if (!fixed_point32_empower::gt(total_debts_value, fixed_point32_empower::from_u64(LIQUIDATION_DUST_THRESHOLD_USD))) {
      return total_debt_amount
    };

    // Normal case: cap per-call repayment at 20% of the *total* outstanding debt
    // value across all types, converted back to DebtType token units.
    // This ensures each liquidation call removes at most 20% of the portfolio's
    // total debt value regardless of which debt type is chosen, preventing
    // incremental over-liquidation across multiple debt types.
    //
    // Derivation (FixedPoint32 raw values carry an implicit 2^32 scale):
    //   max_repay_usd   = 20% * total_debts_value
    //                   = total_debts_value_raw / 2^32 * (1/LIQUIDATION_CAP_DIVISOR)     [USD]
    //   max_repay_tokens = max_repay_usd / debt_price * debt_scale
    //                   = (total_debts_value_raw / LIQUIDATION_CAP_DIVISOR) / (debt_price_raw / 2^32) / 2^32 * debt_scale
    //                   = total_debts_value_raw * debt_scale / (LIQUIDATION_CAP_DIVISOR * debt_price_raw)
    // Working at the raw u64 level avoids any FixedPoint32 rounding from 1/LIQUIDATION_CAP_DIVISOR.
    let debt_price = get_price(x_oracle, debt_type, clock);
    let debt_decimals = coin_decimals_registry::decimals(coin_decimals_registry, debt_type);
    let debt_scale = math::pow(10, debt_decimals);
    let total_debts_value_raw = fixed_point32::get_raw_value(total_debts_value);
    let debt_price_raw = fixed_point32::get_raw_value(debt_price);
    // LIQUIDATION_CAP_DIVISOR (= 5) enforces the 20% per-call repayment cap.
    // Dividing by it in the denominator is equivalent to multiplying the USD value by 0.2.
    // The cap is intentionally applied to the *total* debt value across all types — not just
    // the DebtType balance — so that splitting a position across multiple debt assets cannot
    // be used to liquidate more than 20% of the portfolio's total value in a single call.
    // Raising this value tightens the cap (e.g. 10 → 10%); lowering it relaxes it (e.g. 2 → 50%).
    let max_repay = u64::mul_div(total_debts_value_raw, debt_scale, LIQUIDATION_CAP_DIVISOR * debt_price_raw);
    math::min(max_repay, total_debt_amount)
  }

  /// Converts a debt repayment amount into the collateral amounts awarded to the
  /// liquidator and the protocol during a liquidation event.
  ///
  /// The base exchange rate converts debt tokens to collateral tokens at market prices:
  ///   exchange_rate = (collateral_scale / debt_scale) * (debt_price / collateral_price)
  ///
  /// From this, the two collateral amounts are derived:
  ///   liquidator_amount = debt_amount * exchange_rate * (1 + liq_discount)
  ///   protocol_amount   = debt_amount * exchange_rate * liq_revenue_factor
  ///
  /// The liquidator receives a bonus above market rate (`liq_discount`) as an incentive
  /// to perform liquidations. The protocol collects a fraction (`liq_revenue_factor`)
  /// as liquidation revenue.
  ///
  /// Note: this function does not cap against the borrower's available collateral balance;
  /// the caller is responsible for ensuring sufficient collateral exists.
  public fun debt_to_collateral_amount<DebtType, CollateralType>(
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    debt_amount: u64,
    clock: &Clock,
  ): (u64, u64) {
    let collateral_type = type_name::get<CollateralType>();
    let debt_type = type_name::get<DebtType>();

    let risk_model = market::risk_model(market, collateral_type);
    let liq_discount = risk_model::liq_discount(risk_model);
    let liq_revenue_factor = risk_model::liq_revenue_factor(risk_model);

    let collateral_scale = math::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, collateral_type));
    let debt_scale = math::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, debt_type));
    let collateral_price = get_price(x_oracle, collateral_type, clock);
    let debt_price = get_price(x_oracle, debt_type, clock);

    // Base exchange rate: collateral tokens per debt token at market prices
    // exchange_rate = (collateral_scale / debt_scale) * (debt_price / collateral_price)
    let exchange_rate = fixed_point32_empower::mul(
      fixed_point32::create_from_rational(collateral_scale, debt_scale),
      fixed_point32_empower::div(debt_price, collateral_price),
    );

    // Pre-compute the full conversion rates as FixedPoint32 before the final u64
    // multiplication to preserve maximum precision in intermediate calculations.
    let liquidator_rate = fixed_point32_empower::mul(
      exchange_rate,
      fixed_point32_empower::add(fixed_point32_empower::from_u64(1), liq_discount),
    );
    let protocol_rate = fixed_point32_empower::mul(exchange_rate, liq_revenue_factor);

    let liquidator_amount = fixed_point32::multiply_u64(debt_amount, liquidator_rate);
    let protocol_amount = fixed_point32::multiply_u64(debt_amount, protocol_rate);

    (liquidator_amount, protocol_amount)
  }

  /// Compute the actual repay amount and the collateral split (liquidator / protocol)
  /// for a liquidation, capped by the obligation's available collateral.
  ///
  /// Formula:
  ///   actual_repay = min(available_repay, max_repay_for_debt)
  ///   (liq_amount, protocol_amount) = debt_to_collateral_amount(actual_repay)
  ///   If liq_amount + protocol_amount > obligation collateral, both are scaled down proportionally.
  ///
  /// Returns (actual_repay, liq_amount, protocol_amount).
  public fun calculate_liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
    available_repay_amount: u64,
  ): (u64, u64, u64) {
    // Determine the maximum this liquidator may repay for the given debt type
    let max_repay = max_repay_amount<DebtType>(obligation, market, coin_decimals_registry, x_oracle, clock);
    let actual_repay = math::min(available_repay_amount, max_repay);
    assert!(actual_repay > 0, error::unable_to_liquidate_error());

    // Convert debt amount to collateral amounts (liquidator share includes bonus)
    let (liq_amount, protocol_amount) = debt_to_collateral_amount<DebtType, CollateralType>(
      market, coin_decimals_registry, x_oracle, actual_repay, clock
    );

    // Cap by the obligation's available collateral, scaling proportionally.
    // When collateral is insufficient all three values are scaled by the same
    // ratio (total_collateral / total_needed) so the liquidator only pays for
    // the collateral they actually receive and does not incur a loss.
    let total_collateral = obligation::collateral(obligation, type_name::get<CollateralType>());
    let total_needed = liq_amount + protocol_amount;
    let (actual_repay, liq_amount, protocol_amount) = if (total_needed > total_collateral) {
      let scaled_repay = u64::mul_div(actual_repay, total_collateral, total_needed);
      let scaled_liq = u64::mul_div(total_collateral, liq_amount, total_needed);
      let scaled_protocol = total_collateral - scaled_liq;
      (scaled_repay, scaled_liq, scaled_protocol)
    } else {
      (actual_repay, liq_amount, protocol_amount)
    };
    assert!(liq_amount > 0, error::unable_to_liquidate_error());
    assert!(actual_repay > 0, error::unable_to_liquidate_error());

    (actual_repay, liq_amount, protocol_amount)
  }

  /// @deprecated
  /// calculate the liquidation exchange rate
  /// Debt to Collateral ratio for liquidator
  fun calc_liq_exchange_rate<DebtType, CollateralType>(
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): FixedPoint32 {
    let collateral_type = type_name::get<CollateralType>();
    let debt_type = type_name::get<DebtType>();
    let collateral_decimals = coin_decimals_registry::decimals(coin_decimals_registry, collateral_type);
    let debt_decimals = coin_decimals_registry::decimals(coin_decimals_registry, debt_type);
    let collateral_scale = math::pow(10, collateral_decimals);
    let debt_scale = math::pow(10, debt_decimals);
    let collateral_price = get_price(x_oracle, collateral_type, clock);
    let debt_price = get_price(x_oracle, debt_type, clock);
    let risk_model = market::risk_model(market, collateral_type);
    let liq_discount = risk_model::liq_discount(risk_model);


    // exchange_rate = collateral_scale / debt_scale * debt_price / collateral_price
    let exchange_rate = fixed_point32_empower::mul(
      fixed_point32::create_from_rational(collateral_scale, debt_scale),
      fixed_point32_empower::div(debt_price, collateral_price),
    );
    // liq_exchange_rate = exchange_rate / (1 - liq_discount)
    let liq_exchange_rate = fixed_point32_empower::div(
      exchange_rate,
      fixed_point32_empower::sub(fixed_point32_empower::from_u64(1), liq_discount)
    );

    liq_exchange_rate
  }
}
