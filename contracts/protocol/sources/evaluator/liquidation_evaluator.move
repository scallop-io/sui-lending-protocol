module protocol::liquidation_evaluator {
  use std::type_name;
  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use sui::math;
  use sui::clock::Clock;
  use math::fixed_point32_empower;
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

  // calculate the actual repay amount, actual liquidate amount, actual market amount
  public fun liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    available_repay_amount: u64,
    x_oracle: &XOracle,
    clock: &Clock,
  ): (u64, u64, u64) {

    let collateral_type = type_name::get<CollateralType>();
    let risk_model = market::risk_model(market, collateral_type);
    let liq_revenue_factor = risk_model::liq_revenue_factor(risk_model);

    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(obligation, market, coin_decimals_registry, x_oracle, clock);

    let (actual_repay_amount, actual_liq_amount) = if (available_repay_amount >= max_repay_amount) {
      (max_repay_amount, max_liq_amount)
    } else {
      let liq_exchange_rate = calc_liq_exchange_rate<DebtType, CollateralType>(market, coin_decimals_registry, x_oracle, clock);
      let actual_repay_amount = available_repay_amount;
      let actual_liq_amount = fixed_point32::multiply_u64(actual_repay_amount, liq_exchange_rate);
      (actual_repay_amount, actual_liq_amount)
    };

    // actual_repay_revenue is the reserve for the protocol when liquidating
    let actual_repay_revenue = fixed_point32::multiply_u64(actual_repay_amount, liq_revenue_factor);
    // actual_replay_on_behalf is the amount that is repaid on behalf of the borrower, which should be deducted from the borrower's obligation
    let actual_replay_on_behalf = actual_repay_amount - actual_repay_revenue;

    (actual_replay_on_behalf, actual_repay_revenue, actual_liq_amount)
  }

  // calculate the maximum repay amount, max liquidate amount
  public fun max_liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): (u64, u64) {

    let debt_type = type_name::get<DebtType>();

    // get all the necessary parameters for liquidation
    let collateral_type = type_name::get<CollateralType>();
    let total_collateral_amount = obligation::collateral(obligation, collateral_type);
    let collateral_decimals = coin_decimals_registry::decimals(coin_decimals_registry, collateral_type);
    let collateral_scale = math::pow(10, collateral_decimals);
    let interest_model = market::interest_model(market, debt_type);
    let borrow_weight = interest_model::borrow_weight(interest_model);
    let risk_model = market::risk_model(market, collateral_type);
    let liq_penalty = risk_model::liq_penalty(risk_model);
    let liq_factor = risk_model::liq_factor(risk_model);
    let collateral_price = get_price(x_oracle, collateral_type, clock);

    // calculate the value of collaterals and debts for liquidation
    let collaterals_value = collaterals_value_usd_for_liquidation(obligation, market, coin_decimals_registry, x_oracle, clock);
    let weighted_debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);

    // when collaterals_value >= weighted_debts_value, the obligation is not liquidatable
    assert!(fixed_point32_empower::gt(weighted_debts_value, collaterals_value), error::unable_to_liquidate_error());

    // max_liq_value = (weighted_debts_value - collaterals_value) / (borrow_weight * (1 - liq_penalty) - liq_factor)
    let max_liq_value = fixed_point32_empower::div(
      fixed_point32_empower::sub(weighted_debts_value, collaterals_value),
      fixed_point32_empower::sub(
        fixed_point32_empower::mul(
          borrow_weight,
          fixed_point32_empower::sub(
            fixed_point32_empower::from_u64(1),
            liq_penalty)
        ),
        liq_factor
      ),
    );

    // max_liq_amount = max_liq_value * collateral_scale / collateral_price
    let max_liq_amount = fixed_point32::multiply_u64(
      collateral_scale,
      fixed_point32_empower::div(max_liq_value, collateral_price)
    );
    // max_liq_amount = min(max_liq_amount, total_collateral_amount)
    let max_liq_amount = math::min(max_liq_amount, total_collateral_amount);

    let liq_exchange_rate = calc_liq_exchange_rate<DebtType, CollateralType>(market, coin_decimals_registry, x_oracle, clock);

    // max_repay_amount = max_liq_amount / liq_exchange_rate
    let max_repay_amount = fixed_point32::divide_u64(max_liq_amount, liq_exchange_rate);

    // max_repay_amount = min(max_repay_amount, total_debt_amount)
    let (total_debt_amount, _) = obligation::debt(obligation, debt_type);

    let (max_repay_amount, max_liq_amount) = if (max_repay_amount <= total_debt_amount) {
      (max_repay_amount, max_liq_amount)
    } else {
      (total_debt_amount, fixed_point32::multiply_u64(total_debt_amount, liq_exchange_rate))
    };

    (max_repay_amount, max_liq_amount)
  }

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
