module protocol::collateral_value {
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::risk_model;
  use protocol::price::get_price;
  use protocol::value_calculator::usd_value;
  use x_oracle::x_oracle::XOracle;
  use coin_decimals_registry::coin_decimals_registry::{Self, CoinDecimalsRegistry};

  // sum of every collateral usd value for borrow
  // value = price x amount x collateralFactor
  public fun collaterals_value_usd_for_borrow(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
  ): FixedPoint32 {
    let collateral_types = obligation::collateral_types(obligation);
    let total_value_usd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateral_types));
    while( i < n ) {
      let collateral_type = *vector::borrow(&collateral_types, i);
      let decimals = coin_decimals_registry::decimals(coin_decimals_registry, collateral_type);
      let collateral_amount = obligation::collateral(obligation, collateral_type);
      let risk_model = market::risk_model(market, collateral_type);
      let collateral_factor = risk_model::collateral_factor(risk_model);
      let coin_price = get_price(x_oracle, collateral_type);
      let collateral_value_usd = fixed_point32_empower::mul(
        usd_value(coin_price, collateral_amount, decimals),
        collateral_factor,
      );
      total_value_usd = fixed_point32_empower::add(total_value_usd, collateral_value_usd);
      i = i + 1;
    };
    total_value_usd
  }
  
  // sum of every collateral usd value for liquidation
  // value = price x amount x liquidationFactor
  public fun collaterals_value_usd_for_liquidation(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_regsitry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
  ): FixedPoint32 {
    let collateral_types = obligation::collateral_types(obligation);
    let total_value_usd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&collateral_types));
    while( i < n ) {
      let collateral_type = *vector::borrow(&collateral_types, i);
      let decimals = coin_decimals_registry::decimals(coin_decimals_regsitry, collateral_type);
      let collateral_amount = obligation::collateral(obligation, collateral_type);
      let risk_model = market::risk_model(market, collateral_type);
      let liq_factor = risk_model::liq_factor(risk_model);
      let coin_price = get_price(x_oracle, collateral_type);
      let collateral_value_usd = fixed_point32_empower::mul(
        usd_value(coin_price, collateral_amount, decimals),
        liq_factor,
      );
      total_value_usd = fixed_point32_empower::add(total_value_usd, collateral_value_usd);
      i = i + 1;
    };
    total_value_usd
  }
}
