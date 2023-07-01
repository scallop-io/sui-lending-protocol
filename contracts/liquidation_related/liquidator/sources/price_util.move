module scallop_liquidator::price_util {

  use std::fixed_point32;
  use std::fixed_point32::FixedPoint32;
  use std::type_name::get;
  use sui::clock::Clock;
  use sui::math;

  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use math::fixed_point32_empower;
  use x_oracle::x_oracle::XOracle;

  use protocol::market::{Self ,Market};
  use protocol::price::get_price;
  use protocol::risk_model;

  /// Evaluate the USD value of a given amount of coins.
  public fun evaluate_usd_value<CoinType>(
    oracle: &XOracle,
    coin_decimals_registry: &CoinDecimalsRegistry,
    amount: u64,
    clock: &Clock,
  ): FixedPoint32 {
    let coin_type = get<CoinType>();
    let coin_decimal = coin_decimals_registry::decimals(coin_decimals_registry, coin_type);
    let coin_price = get_price(oracle, coin_type, clock);
    let coin_decimal_amount = fixed_point32::create_from_rational(amount, math::pow(10, coin_decimal));
    let coin_value_usd = fixed_point32_empower::mul(coin_price, coin_decimal_amount);
    coin_value_usd
  }

  /// Make sure the liquidation is profitable
  public fun is_liquidation_profitable<CoinType>(
    oracle: &XOracle,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    amount: u64,
    clock: &Clock,
  ): bool {
    let coin_type = get<CoinType>();
    let usd_value = evaluate_usd_value<CoinType>(oracle, coin_decimals_registry, amount, clock);
    let risk_model = market::risk_model(market, coin_type);
    let liquidation_discount = risk_model::liq_discount(risk_model);
    // For swap on Cetus, suppose the slippage is 2%, and the swap fee is 0.25%.
    let cetus_loss_rate = fixed_point32::create_from_rational(225, 10000);
    let profit_rate = fixed_point32_empower::sub(liquidation_discount, cetus_loss_rate);
    let profit = fixed_point32_empower::mul(usd_value, profit_rate);
    // The profit should be greater than the gas fee, normally gas fee is around 0.1 USD.
    let gas_cost = fixed_point32::create_from_rational(1, 10);
    // Make sure the profit is greater than the gas fee.
    fixed_point32_empower::gt(profit, gas_cost)
  }
}
