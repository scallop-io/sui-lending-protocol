/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for position
*/
module protocol::borrow_withdraw_evaluator {
  use std::type_name::get;
  use std::fixed_point32;
  use sui::math;
  use math::fixed_point32_empower;
  use protocol::price;
  use protocol::position::Position;
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::collateral_value::collaterals_value_usd_for_borrow;
  use protocol::debt_value::debts_value_usd;
  use protocol::risk_model;
  
  public fun max_borrow_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let collaterals_value = collaterals_value_usd_for_borrow(position, bank, coinDecimalsRegsitry);
    let debts_value = debts_value_usd(position, coinDecimalsRegsitry);
    if (fixed_point32_empower::gt(collaterals_value, debts_value)) {
      let coinType = get<T>();
      let coinDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, coinType);
      let netValue = fixed_point32_empower::sub(collaterals_value, debts_value);
      let coinPrice = price::get_price(coinType);
      fixed_point32::multiply_u64(
        math::pow(10, coinDecimals),
        fixed_point32_empower::div(netValue, coinPrice)
      )
    } else {
      0
    }
  }
  
  public fun max_withdraw_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let maxBorrowAmount = max_borrow_amount<T>(position, bank, coinDecimalsRegsitry);
    let coinType = get<T>();
    let riskModel = bank::risk_model(bank, coinType);
    let collateralFactor = risk_model::collateral_factor(riskModel);
    fixed_point32::divide_u64(maxBorrowAmount, collateralFactor)
  }
}
