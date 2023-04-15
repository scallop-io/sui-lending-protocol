module protocol::debt_value {
  
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::price::value_usd;
  use protocol::interest_model as interest_model_lib;
  use protocol::market::{Self as market_lib, Market};
  
  public fun debts_value_usd(
    obligation: &Obligation,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): FixedPoint32 {
    let debtTypes = obligation::debt_types(obligation);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&debtTypes));
    while( i < n ) {
      let debtType = *vector::borrow(&debtTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
      let (debtAmount, _) = obligation::debt(obligation, debtType);
      let coinValueInUsd = value_usd(debtType, debtAmount, decimals);
      totalValudInUsd = fixed_point32_empower::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }

  public fun debts_value_usd_with_weight(
    obligation: &Obligation,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    market: &Market,
  ): FixedPoint32 {
    let debtTypes = obligation::debt_types(obligation);
    let totalValueInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&debtTypes));
    while( i < n ) {
      let debtType = *vector::borrow(&debtTypes, i);
      let interest_model = market_lib::interest_model(market, debtType);
      let borrow_weight = interest_model_lib::borrow_weight(interest_model);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
      let (debtAmount, _) = obligation::debt(obligation, debtType);
      let coinValueInUsd = value_usd(debtType, debtAmount, decimals);
      let weightedValueInUsd = fixed_point32_empower::mul(coinValueInUsd, borrow_weight);
      totalValueInUsd = fixed_point32_empower::add(totalValueInUsd, weightedValueInUsd);
      i = i + 1;
    };
    totalValueInUsd
  }
}
