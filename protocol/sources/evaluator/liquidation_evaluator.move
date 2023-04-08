module protocol::liquidation_evaluator {
  use std::type_name::get;
  use std::fixed_point32;
  use sui::math;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::debt_value::debts_value_usd;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::price::{get_price};
  use protocol::risk_model;
  
  const ENotLiquidatable: u64 = 0;
  
  // calculate the actual repay amount, actual liquidate amount, actual market amount
  public fun liquidation_amounts<DebtType, CollateralType>(
    obligation: &Obligation,
    market: &Market,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    availableRepayAmount: u64
  ): (u64, u64, u64) {
    let debtType = get<DebtType>();
    let collateralType = get<CollateralType>();
    let totalCollateralAmount = obligation::collateral(obligation, collateralType);
    let debtDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
    let collateralDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
    let debtScale = math::pow(10, debtDecimals);
    let collateralScale = math::pow(10, collateralDecimals);
    let riskModel = market::risk_model(market, collateralType);
    let liqDiscount = risk_model::liq_discount(riskModel);
    let liqPenalty = risk_model::liq_penalty(riskModel);
    let liqFactor = risk_model::liq_factor(riskModel);
    let liqRevenueFactor = risk_model::liq_revenue_factor(riskModel);
    let debtPrice = get_price(debtType);
    let collateralPrice = get_price(collateralType);
    
    let collateralsValue = collaterals_value_usd_for_liquidation(obligation, market, coinDecimalsRegsitry);
    let debtsValue = debts_value_usd(obligation, coinDecimalsRegsitry);
    if (fixed_point32_empower::gt(debtsValue, collateralsValue) == false) return (0, 0, 0);
   
    let maxLiqValue = fixed_point32_empower::div(
      fixed_point32_empower::sub(debtsValue, collateralsValue),
      fixed_point32_empower::sub(fixed_point32_empower::from_u64(1), fixed_point32_empower::add(liqPenalty, liqFactor))
    );
    
    let maxLiqAmount = fixed_point32::multiply_u64(
      collateralScale,
      fixed_point32_empower::div(maxLiqValue, collateralPrice)
    );
    let maxLiqAmount = math::min(maxLiqAmount, totalCollateralAmount);
    
    let exchangeRate = fixed_point32_empower::mul(
      fixed_point32::create_from_rational(collateralScale, debtScale),
      fixed_point32_empower::div(debtPrice, collateralPrice),
    );
    let liqExchangeRate = fixed_point32_empower::div(
      exchangeRate,
      fixed_point32_empower::sub(fixed_point32_empower::from_u64(1), liqDiscount)
    );
    
    let liqAmountAtBest = fixed_point32::multiply_u64(availableRepayAmount, liqExchangeRate);
  
    let actualRepayAmount = availableRepayAmount;
    let actualLiqAmount = liqAmountAtBest;
    if (actualLiqAmount > maxLiqAmount) {
      actualLiqAmount = maxLiqAmount;
      actualRepayAmount = fixed_point32::divide_u64(maxLiqAmount, liqExchangeRate);
    };
    
    let actualRepayRevenue = fixed_point32::multiply_u64(actualRepayAmount, liqRevenueFactor);
    let actualRepayOnBehalf = actualRepayAmount - actualRepayRevenue;
    (actualRepayOnBehalf, actualRepayRevenue, actualLiqAmount)
  }
}
