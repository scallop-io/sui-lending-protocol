module protocol::liquidation_evaluator {
  use std::type_name::get;
  use sui::math;
  use math::mix;
  use math::fr;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::debt_value::debts_value_usd;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::price::{get_price};
  use protocol::risk_model;
  use std::debug;
  
  const ENotLiquidatable: u64 = 0;
  
  // calculate the actual repay amount, actual liquidate amount, actual reserve amount
  public fun liquidation_amounts<DebtType, CollateralType>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    availableRepayAmount: u64
  ): (u64, u64, u64) {
    let debtType = get<DebtType>();
    let collateralType = get<CollateralType>();
    let totalCollateralAmount = position::collateral(position, collateralType);
    let debtDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
    let collateralDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
    let debtScale = math::pow(10, debtDecimals);
    let collateralScale = math::pow(10, collateralDecimals);
    let riskModel = bank::risk_model(bank, collateralType);
    let liqDiscount = risk_model::liq_discount(riskModel);
    let liqPanelty = risk_model::liq_panelty(riskModel);
    let liqFactor = risk_model::liq_factor(riskModel);
    let liqReserveFactor = risk_model::liq_reserve_factor(riskModel);
    let debtPrice = get_price(debtType);
    let collateralPrice = get_price(collateralType);
    
    let collateralsValue = collaterals_value_usd_for_liquidation(position, bank, coinDecimalsRegsitry);
    let debtsValue = debts_value_usd(position, coinDecimalsRegsitry);
    debug::print(&debtsValue);
    debug::print(&collateralsValue);
    if (fr::gt(debtsValue, collateralsValue) == false) return (0, 0, 0);
   
    let maxLiqValue = fr::div(
      fr::sub(debtsValue, collateralsValue),
      mix::sub_ifr(1, fr::add(liqPanelty, liqFactor))
    );
    
    let maxLiqAmount = fr::divT(
      mix::mul_ifr(collateralScale, maxLiqValue),
      collateralPrice
    );
    let maxLiqAmount = math::min(maxLiqAmount, totalCollateralAmount);
    
    let exchangeRate = fr::div(
      mix::mul_ifr(collateralScale, debtPrice),
      mix::mul_ifr(debtScale, collateralPrice),
    );
    let liqExchangeRate = fr::div(exchangeRate, mix::sub_ifr(1,liqDiscount));
    
    let liqAmountAtBest = fr::mul_iT(liqExchangeRate, availableRepayAmount);
  
    let actualRepayAmount = availableRepayAmount;
    let actualLiqAmount = liqAmountAtBest;
    if (actualLiqAmount > maxLiqAmount) {
      actualLiqAmount = maxLiqAmount;
      actualRepayAmount = mix::div_ifrT(maxLiqAmount, liqExchangeRate);
    };
    
    let actualRepayReserve = mix::mul_ifrT(actualRepayAmount, liqReserveFactor);
    let actualRepayOnBehalf = actualRepayAmount - actualRepayReserve;
    (actualRepayOnBehalf, actualRepayReserve, actualLiqAmount)
  }
}
