module protocol::liquidation_evaluator {
  use std::type_name::{Self, TypeName};
  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use sui::math;
  use sui::clock::Clock;
  use math::fixed_point32_empower;
  use math::u64;
  use protocol::obligation::{Self, Obligation};
  use protocol::interest_model;
  use protocol::market::{Self, Market};
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::risk_model;
  use protocol::error;
  use protocol::price::get_price;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

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
  /// The maximum repay amount is derived from the shortfall ("bad debt"):
  ///   bad_debt_value   = weighted_debts_value - collaterals_value  (USD)
  ///   max_repay_value  = bad_debt_value / borrow_weight            (USD, unweighted)
  ///   max_repay_amount = max_repay_value * debt_scale / debt_price (debt token units)
  ///
  /// The result is capped by the borrower's total outstanding debt of this type,
  /// ensuring the liquidator cannot repay more than what is owed.
  ///
  /// Returns 0 if the obligation is healthy (not liquidatable).
  ///
  /// Example 1 — borrow_weight = 1.0 (e.g. USDC, decimals=6, price=$1):
  ///   weighted_debts_value = $1200, collaterals_value = $1000
  ///   bad_debt_value   = $1200 - $1000 = $200
  ///   max_repay_value  = $200 / 1.0 = $200
  ///   max_repay_amount = $200 * 1_000_000 / $1 = 200_000_000 (200 USDC)
  ///   If total outstanding USDC debt is 150 USDC, result is capped to 150_000_000.
  ///
  /// Example 2 — borrow_weight = 2.0 (e.g. volatile token XYZ, decimals=8, price=$50):
  ///   weighted_debts_value = $1500, collaterals_value = $1000
  ///   bad_debt_value   = $1500 - $1000 = $500
  ///   max_repay_value  = $500 / 2.0 = $250
  ///   max_repay_amount = $250 * 100_000_000 / $50 = 500_000_000 (5 XYZ)
  ///   A higher borrow_weight means each dollar of debt counts more toward the
  ///   shortfall, but the liquidator only needs to repay the unweighted amount.
  public fun max_repay_amount<DebtType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let debt_type = type_name::get<DebtType>();

    let interest_model = market::interest_model(market, debt_type);
    let borrow_weight = interest_model::borrow_weight(interest_model);
    let debt_scale = math::pow(10, coin_decimals_registry::decimals(coin_decimals_registry, debt_type));
    let debt_price = get_price(x_oracle, debt_type, clock);

    // Compute portfolio values: collateral (liquidation-adjusted) vs weighted debts
    let collaterals_value = collaterals_value_usd_for_liquidation(obligation, market, coin_decimals_registry, x_oracle, clock);
    let weighted_debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);

    // Obligation is healthy — not eligible for liquidation
    if (!fixed_point32_empower::gt(weighted_debts_value, collaterals_value)) {
      return 0
    };

    // Compute the full conversion rate in FixedPoint32 before the final u64
    // multiplication to preserve maximum precision:
    // repay_rate = bad_debt_value / (debt_price * borrow_weight)
    // max_repay_amount = debt_scale * repay_rate
    let bad_debt_value = fixed_point32_empower::sub(weighted_debts_value, collaterals_value);
    let repay_rate = fixed_point32_empower::div(
      bad_debt_value,
      fixed_point32_empower::mul(debt_price, borrow_weight),
    );
    let max_repay_amount = fixed_point32::multiply_u64(debt_scale, repay_rate);

    // Cap by the borrower's total outstanding debt of this type
    let (total_debt_amount, _) = obligation::debt(obligation, debt_type);
    math::min(max_repay_amount, total_debt_amount)
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
    collateral_type: TypeName,
  ): (u64, u64, u64) {
    // Determine the maximum this liquidator may repay for the given debt type
    let max_repay = max_repay_amount<DebtType>(obligation, market, coin_decimals_registry, x_oracle, clock);
    let actual_repay = math::min(available_repay_amount, max_repay);
    assert!(actual_repay > 0, error::unable_to_liquidate_error());

    // Convert debt amount to collateral amounts (liquidator share includes bonus)
    let (liq_amount, protocol_amount) = debt_to_collateral_amount<DebtType, CollateralType>(
      market, coin_decimals_registry, x_oracle, actual_repay, clock
    );

    // Cap by the obligation's available collateral, scaling proportionally
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
