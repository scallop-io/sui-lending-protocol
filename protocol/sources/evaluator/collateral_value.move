module protocol::collateral_value {
  use std::vector;
  use math::fr::{Self, Fr};
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::price::value_usd;
  use protocol::risk_model;
  
  // sum of every collateral usd value for borrow
  // value = price x amount x collateralFactor
  public fun collaterals_value_usd_for_borrow(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): Fr {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = fr::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
      let collateralAmount = position::collateral(position, collateralType);
      let riskModel = bank::risk_model(bank, collateralType);
      let collateralFactor = risk_model::collateral_factor(riskModel);
      let coinValueInUsd = fr::mul(
        value_usd(collateralType, collateralAmount, decimals),
        collateralFactor,
      );
      totalValudInUsd = fr::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
  
  // sum of every collateral usd value for liquidation
  // value = price x amount x liquidationFactor
  public fun collaterals_value_usd_for_liquidation(
    position: &Position,
    bank: &Bank,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
  ): Fr {
    let collateralTypes = position::collateral_types(position);
    let totalValudInUsd = fr::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
      let collateralAmount = position::collateral(position, collateralType);
      let riskModel = bank::risk_model(bank, collateralType);
      let liqFactor = risk_model::liq_factor(riskModel);
      let coinValueInUsd = fr::mul(
        value_usd(collateralType, collateralAmount, decimals),
        liqFactor,
      );
      totalValudInUsd = fr::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
}
