module protocol::liquidation_evaluator {
  use std::type_name::get;
  use math::mix;
  use math::fr;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::debt_evaluator::debts_value_usd;
  use protocol::collateral_evaluator::collaterals_value_usd_for_liquidation;
  use protocol::price::{coin_amount, get_price, exchange_rate};
  
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
      mix::sub_ifr(1, fr::add(liquidationPanelty, liquidationFactor))
    );
    let collateralDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
    let maxLiquidatableCollateralAmount = coin_amount(
      collateralType, maxLiquidatableCollateralValueUSD, collateralDecimals
    );
    
    let collateralAmount = position::collateral(position, collateralType);
    let actualLiquidatableCollateralAmount = if (maxLiquidatableCollateralAmount > collateralAmount) {
      collateralAmount
    } else {
      maxLiquidatableCollateralAmount
    };
    
    let debtDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
    let collateralDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
    let exchangeRate = exchange_rate(debtType, debtDecimals, collateralType, collateralDecimals);
    let liquidationDiscount = bank::liquidation_discount(bank, collateralType);
    let maxRepayAmount = mix::mul_ifrT(
      actualLiquidatableCollateralAmount,
      fr::div(exchangeRate, liquidationDiscount)
    );
    return maxRepayAmount
  }
}
