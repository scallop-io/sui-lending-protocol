module protocol::collateral_value {
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::position::{Self, Position};
  use protocol::reserve::{Self, Reserve};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::risk_model;
  use protocol::price::value_usd;
  
  // sum of every collateral usd value for borrow
  // value = price x amount x collateralFactor
  public fun collaterals_value_usd_for_borrow(
    position: &Position,
    reserve: &Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
  ): FixedPoint32 {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegistry, collateralType);
      let collateralAmount = position::collateral(position, collateralType);
      let riskModel = reserve::risk_model(reserve, collateralType);
      let collateralFactor = risk_model::collateral_factor(riskModel);
      let coinValueInUsd = fixed_point32_empower::mul(
        value_usd(collateralType, collateralAmount, decimals),
        collateralFactor,
      );
      totalValudInUsd = fixed_point32_empower::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
  
  // sum of every collateral usd value for liquidation
  // value = price x amount x liquidationFactor
  public fun collaterals_value_usd_for_liquidation(
    position: &Position,
    reserve: &Reserve,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): FixedPoint32 {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
      let collateralAmount = position::collateral(position, collateralType);
      let riskModel = reserve::risk_model(reserve, collateralType);
      let liqFactor = risk_model::liq_factor(riskModel);
      let coinValueInUsd = fixed_point32_empower::mul(
        value_usd(collateralType, collateralAmount, decimals),
        liqFactor,
      );
      totalValudInUsd = fixed_point32_empower::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
}
