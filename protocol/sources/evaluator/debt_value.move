module protocol::debt_value {
  
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::price::value_usd;
  
  // sum of every debt usd value
  // value = price x amount
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
}
