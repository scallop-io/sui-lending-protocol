/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for position
*/
module mobius_core::evaluator {
  use std::vector;
  
  use mobius_core::collateral_config::CollateralConfig;
  use mobius_core::token_stats;
  use mobius_core::collateral_config;
  use mobius_core::price;
  use math::exponential::{Self, Exp};
  use mobius_core::token_stats::{Stat, TokenStats};
  use std::type_name::get;
  
  public fun max_borrow_amount<T>(
    collateralTokenStats: &TokenStats,
    debtTokenStats: &TokenStats,
    collateralConfig: &CollateralConfig
  ): u64 {
    let collaterals_value = calc_collaterals_value(collateralTokenStats, collateralConfig);
    let debts_value = calc_debts_value(debtTokenStats);
    if (exponential::greater_than_exp(collaterals_value, debts_value)) {
      let netValue = exponential::sub_exp(collaterals_value, debts_value);
      let coinType = get<T>();
      let coinPrice = price::get_price(coinType);
      let maxBorrowAmount = exponential::truncate(
        exponential::div_exp(netValue,coinPrice)
      );
      (maxBorrowAmount as u64)
    } else {
      0
    }
  }
  
  public fun max_withdraw_amount<T>(
    collateralTokenStats: &TokenStats,
    debtTokenStats: &TokenStats,
    collateralConfig: &CollateralConfig
  ): u64 {
    let maxBorrowAmount = max_borrow_amount<T>(collateralTokenStats, debtTokenStats, collateralConfig);
    let coinType = get<T>();
    let collateralFactor = collateral_config::collateral_factor(collateralConfig, coinType);
    let maxWithdrawAmount = exponential::truncate(
      exponential::div_scalar_by_exp((maxBorrowAmount as u128), collateralFactor)
    );
    (maxWithdrawAmount as u64)
  }
  
  public fun max_liquidate_amount<T>(
    collateralTokenStats: &TokenStats,
    debtTokenStats: &TokenStats,
    collateralConfig: &CollateralConfig
  ): u64 {
    let collaterals_value = calc_collaterals_value(collateralTokenStats, collateralConfig);
    let debts_value = calc_debts_value(debtTokenStats);
    if (exponential::greater_than_exp(collaterals_value, debts_value)) {
      0
    } else {
      let badDebt = exponential::sub_exp(debts_value, collaterals_value);
      let coinType = get<T>();
      let coinPrice = price::get_price(coinType);
      let max_liquidate_amount = exponential::truncate(
        exponential::div_exp(badDebt, coinPrice)
      );
      (max_liquidate_amount as u64)
    }
  }
  
  // sum of every collateral usd value
  // value = price x amount x collateralFactor
  fun calc_collaterals_value(
    tokenStats: &TokenStats,
    collateralConfig: &CollateralConfig
  ): Exp {
    let collateralStats = token_stats::stats(
      tokenStats,
    );
    let (i, n) = (0u64, vector::length(collateralStats));
    let totalValudInUsd = exponential::exp(0, 1);
    while( i < n ) {
      let stat = vector::borrow(collateralStats, i);
      let coinValueInUsd = exponential::mul_exp(
        calc_token_value(stat),
        collateral_config::collateral_factor(collateralConfig, token_stats::token_type(stat))
      );
      totalValudInUsd = exponential::add_exp(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
  
  // sum of every debt usd value
  // value = price x amount
  fun calc_debts_value(
    tokenStats: &TokenStats,
  ): Exp {
    let debtStats = token_stats::stats(
      tokenStats,
    );
    let (i, n) = (0u64, vector::length(debtStats));
    let totalValudInUsd = exponential::exp(0, 1);
    while( i < n ) {
      let stat = vector::borrow(debtStats, i);
      let coinValueInUsd = calc_token_value(stat);
      totalValudInUsd = exponential::add_exp(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
  
  fun calc_token_value(
    tokenStat: &Stat,
  ): Exp {
    let coinAmount = token_stats::token_amount(tokenStat);
    let coinType = token_stats::token_type(tokenStat);
    let price = price::get_price(coinType);
    exponential::mul_scalar_exp(price, (coinAmount as u128))
  }
}
