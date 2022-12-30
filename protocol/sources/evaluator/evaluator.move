/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for position
*/
module protocol::evaluator {
  use std::type_name::get;
  use sui::math;
  use math::mix;
  use math::fr;
  use protocol::price;
  use protocol::position::Position;
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::collateral_evaluator::collaterals_value_usd_for_borrow;
  use protocol::debt_evaluator::debts_value_usd;
  
  public fun max_borrow_amount<T>(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): u64 {
    let collaterals_value = collaterals_value_usd_for_borrow(position, bank, coinDecimalsRegsitry);
    let debts_value = debts_value_usd(position, coinDecimalsRegsitry);
    if (fr::gt(collaterals_value, debts_value)) {
      let coinType = get<T>();
      let coinDecimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, coinType);
      let netValue = fr::sub(collaterals_value, debts_value);
      let coinPrice = price::get_price(coinType);
      mix::mul_ifrT(
        math::pow(10, coinDecimals),
        fr::div(netValue, coinPrice)
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
    let collateralFactor = bank::collateral_factor(bank, coinType);
    mix::div_ifrT(maxBorrowAmount, collateralFactor)
  }
}
