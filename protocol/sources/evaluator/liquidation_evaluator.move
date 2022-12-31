module protocol::liquidation_evaluator {
  use std::type_name::get;
  use sui::math;
  use math::mix;
  use math::fr;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::debt_evaluator::debts_value_usd;
  use protocol::collateral_evaluator::collaterals_value_usd_for_liquidation;
  use protocol::price::{get_price};
  
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
    let liqDiscount = bank::liquidation_discount(bank, collateralType);
    let liqPanelty = bank::liquidation_panelty(bank, collateralType);
    let liqFactor = bank::liquidation_factor(bank, collateralType);
    let liqReserveFactor = bank::liquidation_reserve_factor(bank, collateralType);
    let debtPrice = get_price(debtType);
    let collateralPrice = get_price(collateralType);
    
    let collateralsValue = collaterals_value_usd_for_liquidation(position, bank, coinDecimalsRegsitry);
    let debtsValue = debts_value_usd(position, coinDecimalsRegsitry);
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
    let liqExchangeRate = fr::div(exchangeRate, liqDiscount);
    
    let liqAmountAtBest = mix::mul_ifrT(availableRepayAmount, liqExchangeRate);
  
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
