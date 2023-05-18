/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for obligation
*/
module protocol::borrow_withdraw_evaluator {
  use std::type_name::get;
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::math;
  use sui::clock::Clock;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::collateral_value::collaterals_value_usd_for_borrow;
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::risk_model;
  use protocol::interest_model;
  use protocol::price::get_price;

  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  public fun available_borrow_amount_in_usd(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): FixedPoint32 {
    let collaterals_value = collaterals_value_usd_for_borrow(obligation, market, coin_decimals_registry, x_oracle, clock);
    let debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);
    if (fixed_point32_empower::gt(collaterals_value, debts_value)) {
      fixed_point32_empower::sub(collaterals_value, debts_value)
    } else {
      fixed_point32_empower::zero()
    }
  }

  /// how much amount of `T` coins can be borrowed
  /// NOTES: borrow weight is applied here!
  public fun max_borrow_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let available_borrow_amount = available_borrow_amount_in_usd(obligation, market, coin_decimals_registry, x_oracle, clock);
    if (fixed_point32_empower::gt(available_borrow_amount, fixed_point32_empower::zero())) {
      let coin_type = get<T>();
      let interest_model = market::interest_model(market, coin_type);
      let borrow_weight = interest_model::borrow_weight(interest_model);
      let coin_decimals = coin_decimals_registry::decimals(coin_decimals_registry, coin_type);
      let coin_price = get_price(x_oracle, coin_type, clock);
      let weighted_coin_price = fixed_point32_empower::mul(coin_price, borrow_weight);
      fixed_point32::multiply_u64(
        math::pow(10, coin_decimals),
        fixed_point32_empower::div(available_borrow_amount, weighted_coin_price)
      )
    } else {
      0
    }
  }
  
  /// maximum amount of `T` token can be withdrawn from collateral
  /// the borrow value is calculated with weight applied
  /// if debts == 0 then user can withdraw all of `T` token from collateral
  /// if debts > 0 then the user can withdraw as much as the collateral amount doesn't below the collateral factor
  public fun max_withdraw_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let coin_type = get<T>();
    let collateral_amount = obligation::collateral(obligation, coin_type);

    let debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);
    if (fixed_point32::is_zero(debts_value)) {
      return collateral_amount
    };

    let available_borrow_amount = available_borrow_amount_in_usd(obligation, market, coin_decimals_registry, x_oracle, clock);
    
    let coin_price = get_price(x_oracle, coin_type, clock);

    let coin_decimals = coin_decimals_registry::decimals(coin_decimals_registry, coin_type);

    let available_withdraw_amount = fixed_point32::multiply_u64(
      math::pow(10, coin_decimals),
      fixed_point32_empower::div(available_borrow_amount, coin_price)
    );

    let risk_model = market::risk_model(market, coin_type);
    let collateral_factor = risk_model::collateral_factor(risk_model);

    math::min(fixed_point32::divide_u64(available_withdraw_amount, collateral_factor), collateral_amount)
  }
}
