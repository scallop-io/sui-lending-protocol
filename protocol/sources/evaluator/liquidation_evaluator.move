module protocol::liquidation_evaluator {
  use std::type_name::get;
  use math::mix;
  use math::fr;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::debt_evaluator::debts_value_usd;
  use protocol::collateral_evaluator::collaterals_value_usd_for_liquidation;
  use protocol::price::{value_usd, coin_amount, get_price};
  
  const ENotLiquidatable: u64 = 0;
  
  // calculate the actual repayamount, and actual liquidate amount
  public fun liquidation_amounts<DebtType, CollateralType>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    availableRepayAmount: u64
  ): (u64, u64, u64) {
    let maxRepayAmount = max_repay_amount_for_liquidation<DebtType, CollateralType>(
      position, bank, coinDecimalsRegsitry
    );
    assert!(maxRepayAmount > 0, ENotLiquidatable);
    
    let debtType = get<DebtType>();
    let collateralType = get<CollateralType>();
    let debtPrice = get_price(debtType);
    let collateralPrice = get_price(collateralType);
    
    let actualRepayAmount = if (availableRepayAmount <= maxRepayAmount) {
      availableRepayAmount
    } else {
      maxRepayAmount
    };
    /*********
    actualLiquidateAmount = actualRepayAmount * (debtPrice / collateralPrice) / (1 - liquidationPanelty)
    **********/
    let liquidationPanelty = bank::liquidation_panelty(bank, collateralType);
    let actualLiquidateAmount = mix::mul_ifrT(
      actualRepayAmount,
      fr::div(
        fr::div(debtPrice, collateralPrice),
        mix::sub_ifr(1, liquidationPanelty)
      )
    );
    let liquidationReserveFactor = bank::liquidation_reserve_factor(bank, collateralType);
    let liquidationDiscount = bank::liquidation_discount(bank, collateralPrice);
    /*********
    actualReserveAmount = actualRepayAmount * liquidationReserveFactor / liquidationDiscount
    **********/
    let actualReserveAmount = mix::div_ifrT(
      actualRepayAmount,
      fr::div(liquidationReserveFactor, liquidationDiscount)
    );
    let actualRepayOnBehalfAmount = actualRepayAmount - actualReserveAmount;
    (actualLiquidateAmount, actualRepayOnBehalfAmount, actualReserveAmount)
  }
  
  // Calculate how much collateral can be liquidated
  // return max repayamount
  fun max_repay_amount_for_liquidation<DebtType, CollateralType>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    /***********
    1.Calc the debts and collaterals value in USD.
      (Notice the collaterals USD value are discounted based on liquidation factor for each collateral)
      if  (collaterals_value_usd > debts_value_usd) return 0
    ************/
    let collaterals_value_usd = collaterals_value_usd_for_liquidation(position, bank, coinDecimalsRegsitry);
    let debts_value_usd = debts_value_usd(position, coinDecimalsRegsitry);
    if (fr::gt(collaterals_value_usd, debts_value_usd)) return 0;
    
    let debtType = get<DebtType>();
    let collateralType = get<CollateralType>();
    let liquidationPanelty = bank::liquidation_panelty(bank, collateralType);
    let liquidationFactor = bank::liquidation_factor(bank, collateralType);
    /***********
    2.Calc the maximum collaterals(in usd) that can be liquidated
      (Can only liquidate to the liquidation line)
      let maxLiquidatableCollateralValueUSD =
        (debts_value_usd - collaterals_value_usd) / (1 - liquidationPenalty - liquidationFactor)
    ************/
    let maxLiquidatableCollateralValueUSD = fr::div(
      fr::sub(debts_value_usd, collaterals_value_usd),
      fr::sub(
        fr::fr(1, 1),
        fr::add(liquidationPanelty, liquidationFactor)
      )
    );
    
    /***********
    3.Calc the total usd value for the collateral type of this position
      let totalPositionCollateralValueUSD = price * decimalAmount
    ************/
    let collateralAmount = position::collateral(position, collateralType);
    let collateralDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
    let collateralValueUSD = value_usd(collateralType, collateralAmount, collateralDecimals);
    
    /***********
    4.The actual collateral usd value that can be liquidated is
      the minimum of collateralValueUSD and maxLiquidatableCollateralValueUSD
    ***********/
    let actualLiquidatableCollateralValueUSD = if (fr::gt(maxLiquidatableCollateralValueUSD, collateralValueUSD)) {
      collateralValueUSD
    } else {
      maxLiquidatableCollateralValueUSD
    };
    
    /***********
    5.The liquidator gets a discount for liquidation, the maximum USD value can be repaid should refect this:
      let maxRepayUSD = actualLiquidatableCollateralValueUSD * liquidationDiscount
    ***********/
    let liquidationDiscount = bank::liquidation_discount(bank, collateralType);
    let maxRepayUSD = fr::mul(actualLiquidatableCollateralValueUSD, liquidationDiscount);
    
    /***********
    6.The max repay amount is calc below:
      let maxRepayAmount = (maxRepayUSD / debtPrice) * (10**decimals)
    ***********/
    let debtDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
    let maxRepayAmount = coin_amount(debtType, maxRepayUSD, debtDecimals);
    return maxRepayAmount
  }
}
