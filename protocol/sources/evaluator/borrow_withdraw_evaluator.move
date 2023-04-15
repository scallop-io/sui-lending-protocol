/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for obligation
*/
module protocol::borrow_withdraw_evaluator {
  use std::type_name::get;
  use std::fixed_point32;
  use sui::math;
  use math::fixed_point32_empower;
  use protocol::price;
  use protocol::obligation::Obligation;
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::collateral_value::collaterals_value_usd_for_borrow;
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::risk_model;
  use protocol::interest_model;
  
  /// how much amount of token can be borrowed
  /// NOTES: borrow weight is applied here!
  public fun max_borrow_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let collaterals_value = collaterals_value_usd_for_borrow(obligation, market, coinDecimalsRegsitry);
    let debts_value = debts_value_usd_with_weight(obligation, coinDecimalsRegsitry, market);
    if (fixed_point32_empower::gt(collaterals_value, debts_value)) {
      let coinType = get<T>();
      let interest_model = market::interest_model(market, coinType);
      let borrow_weight = interest_model::borrow_weight(interest_model);
      let coinDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, coinType);
      let netValue = fixed_point32_empower::sub(collaterals_value, debts_value);
      let coinPrice = price::get_price(coinType);
      let weighted_coin_price = fixed_point32_empower::mul(coinPrice, borrow_weight);
      fixed_point32::multiply_u64(
        math::pow(10, coinDecimals),
        fixed_point32_empower::div(netValue, weighted_coin_price)
      )
    } else {
      0
    }
  }
  
  /// maximum amount of token can be withdrawn
  /// the borrow value is calculated with weight applied
  public fun max_withdraw_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let maxBorrowAmount = max_borrow_amount<T>(obligation, market, coinDecimalsRegsitry);
    let coinType = get<T>();
    let riskModel = market::risk_model(market, coinType);
    let collateralFactor = risk_model::collateral_factor(riskModel);
    fixed_point32::divide_u64(maxBorrowAmount, collateralFactor)
  }
}
