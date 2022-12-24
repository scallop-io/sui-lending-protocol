/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for position
*/
/// TODO: consider decimals when calculating usd value
module mobius_protocol::evaluator {
  use std::vector;
  use std::type_name::{get, TypeName};

  use math::exponential::{Self, Exp};
  use x::ac_table::AcTable;

  use mobius_protocol::price;
  use mobius_protocol::position::{Self, Position};
  use mobius_protocol::collateral_config::{Self, CollateralConfigs, CollateralConfig};
  
  public fun max_borrow_amount<T>(
    position: &Position,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
  ): u64 {
    let collaterals_value = calc_collaterals_value(position, collateralConfigs);
    let debts_value = calc_debts_value(position);
    if (exponential::greater_than_exp(collaterals_value, debts_value)) {
      let coinType = get<T>();
      let netValue = exponential::sub_exp(collaterals_value, debts_value);
      let coinPrice = price::get_price(coinType);
      let maxBorrowAmount = exponential::truncate(
        exponential::div_exp(netValue, coinPrice)
      );
      (maxBorrowAmount as u64)
    } else {
      0
    }
  }

  public fun max_withdraw_amount<T>(
    position: &Position,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
  ): u64 {
    let maxBorrowAmount = max_borrow_amount<T>(position, collateralConfigs);
    let coinType = get<T>();
    let collateralFactor = collateral_config::collateral_factor(collateralConfigs, coinType);
    let maxWithdrawAmount = exponential::truncate(
      exponential::div_scalar_by_exp((maxBorrowAmount as u128), collateralFactor)
    );
    (maxWithdrawAmount as u64)
  }

  public fun max_liquidate_amount<T>(
    position: &Position,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
  ): u64 {
    let collaterals_value = calc_collaterals_value(position, collateralConfigs);
    let debts_value = calc_debts_value(position);
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
    position: &Position,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
  ): Exp {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = exponential::exp(0, 1);
    let (i, n) = (0u64, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let (collateralAmount, _) = position::debt(position, collateralType);
      let collateralFactor = collateral_config::collateral_factor(collateralConfigs, collateralType);
      let coinValueInUsd = exponential::mul_exp(
        calc_token_value(collateralType, collateralAmount),
        collateralFactor,
      );
      totalValudInUsd = exponential::add_exp(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }

  // sum of every debt usd value
  // value = price x amount
  fun calc_debts_value(
    position: &Position,
  ): Exp {
    let debtTypes = position::debt_types(position);
    let totalValudInUsd = exponential::exp(0, 1);
    let (i, n) = (0u64, vector::length(&debtTypes));
    while( i < n ) {
      let debtType = *vector::borrow(&debtTypes, i);
      let (debtAmount, _) = position::debt(position, debtType);
      let coinValueInUsd = calc_token_value(debtType, debtAmount);
      totalValudInUsd = exponential::add_exp(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }

  fun calc_token_value(
    coinType: TypeName,
    coinAmount: u64,
  ): Exp {
    let price = price::get_price(coinType);
    exponential::mul_scalar_exp(price, (coinAmount as u128))
  }
}
