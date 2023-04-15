module protocol::collateral_value {
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::risk_model;
  use oracle::price_feed::{Self, PriceFeedHolder};
  
  // sum of every collateral usd value for borrow
  // value = price x amount x collateralFactor
  public fun collaterals_value_usd_for_borrow(
    obligation: &Obligation,
    market: &Market,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    price_feeds: &PriceFeedHolder,
  ): FixedPoint32 {
    let collateralTypes = obligation::collateral_types(obligation);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegistry, collateralType);
      let collateralAmount = obligation::collateral(obligation, collateralType);
      let riskModel = market::risk_model(market, collateralType);
      let collateralFactor = risk_model::collateral_factor(riskModel);
      let price_feed = price_feed::price_feed(price_feeds, collateralType);
      let coinValueInUsd = fixed_point32_empower::mul(
        price_feed::calculate_coin_in_usd(price_feed, collateralAmount, decimals),
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
    obligation: &Obligation,
    market: &Market,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    price_feeds: &PriceFeedHolder,
  ): FixedPoint32 {
    let collateralTypes = obligation::collateral_types(obligation);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateralTypes));
    while( i < n ) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, collateralType);
      let collateralAmount = obligation::collateral(obligation, collateralType);
      let riskModel = market::risk_model(market, collateralType);
      let liqFactor = risk_model::liq_factor(riskModel);
      let price_feed = price_feed::price_feed(price_feeds, collateralType);
      let coinValueInUsd = fixed_point32_empower::mul(
        price_feed::calculate_coin_in_usd(price_feed, collateralAmount, decimals),
        liqFactor,
      );
      totalValudInUsd = fixed_point32_empower::add(totalValudInUsd, coinValueInUsd);
      i = i + 1;
    };
    totalValudInUsd
  }
}
