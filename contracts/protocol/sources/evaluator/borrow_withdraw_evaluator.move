/**
Evaluate the value of collateral, and debt
Calculate the borrowing power, health factor for obligation
*/
module protocol::borrow_withdraw_evaluator {
use std::type_name;
  use std::uq32_32::{Self, UQ32_32};
  use std::u64;
  use sui::clock::Clock;
  use math::UQ32_32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::collateral_value::collaterals_value_usd_for_borrow;
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::risk_model;
  use protocol::interest_model;
  use protocol::price::get_price;

  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  public fun available_borrow_amount_in_usd(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): UQ32_32 {
    let collaterals_value = collaterals_value_usd_for_borrow(obligation, market, coin_decimals_registry, x_oracle, clock);
    let debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);
    if (UQ32_32_empower::gt(collaterals_value, debts_value)) {
      UQ32_32_empower ::sub(collaterals_value, debts_value)
    } else {
      UQ32_32_empower::zero()
    }
  }

  /// how much amount of `T` coins can be borrowed
  /// NOTES: borrow weight is applied here!
  
  public fun max_borrow_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let available_borrow_amount = available_borrow_amount_in_usd(obligation, market, coin_decimals_registry, x_oracle, clock);
    if (UQ32_32_empower::gt(available_borrow_amount, UQ32_32_empower::zero())) {
      let coin_type = type_name::with_defining_ids<T>();
      let interest_model = market::interest_model(market, coin_type);
      let borrow_weight = interest_model::borrow_weight(interest_model);
      let coin_decimals = coin_decimals_registry::decimals(coin_decimals_registry, coin_type);
      let coin_price = get_price(x_oracle, coin_type, clock);
      let weighted_coin_price = UQ32_32_empower::mul(coin_price, borrow_weight);
      uq32_32::int_mul(
        std::u64::pow(10, coin_decimals),
        UQ32_32_empower::div(available_borrow_amount, weighted_coin_price)
      )
    } else {
      0
    }
  }
  
  /// maximum amount of `T` token can be withdrawn from collateral
  /// the borrow value is calculated with weight applied
  /// if debts == 0 then user can withdraw all of `T` token from collateral
  /// if debts > 0 then the user can withdraw as much as the collateral amount doesn't below the collateral factor
  public fun max_withdraw_amount<T>(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): u64 {
    let coin_type =  type_name::with_defining_ids<T>();
    let collateral_amount = obligation::collateral(obligation, coin_type);

    let debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);
   if (uq32_32::to_raw(debts_value) == 0) {
    return collateral_amount
};
    

    let available_borrow_amount = available_borrow_amount_in_usd(obligation, market, coin_decimals_registry, x_oracle, clock);
    
    let coin_price = get_price(x_oracle, coin_type, clock);

    let coin_decimals = coin_decimals_registry::decimals(coin_decimals_registry, coin_type);

    let available_withdraw_amount = uq32_32::int_mul(
      std::u64::pow(10, coin_decimals),
      UQ32_32_empower::div(available_borrow_amount, coin_price)
    );

    let risk_model = market::risk_model(market, coin_type);
    let collateral_factor = risk_model::collateral_factor(risk_model);

   if (uq32_32::to_raw(collateral_factor) == 0) {
    return if (uq32_32::to_raw(available_borrow_amount) != 0) {
        collateral_amount
    } else {
        0
    }
};

    std::u64::min(uq32_32::int_div(available_withdraw_amount, collateral_factor), collateral_amount)
  }
}
