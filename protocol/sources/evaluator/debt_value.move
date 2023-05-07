module protocol::debt_value {
  
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::interest_model as interest_model_lib;
  use protocol::market::{Self as market_lib, Market};
  use protocol::value_calculator::usd_value;
  use protocol::price::get_price;
  use x_oracle::x_oracle::XOracle;

  public fun debts_value_usd(
    obligation: &Obligation,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
  ): FixedPoint32 {
    let debt_types = obligation::debt_types(obligation);
    let total_value_usd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&debt_types));
    while( i < n ) {
      let debt_type = *vector::borrow(&debt_types, i);
      let decimals = coin_decimals_registry::decimals(coin_decimals_registry, debt_type);
      let (debt_amount, _) = obligation::debt(obligation, debt_type);
      let coin_price = get_price(x_oracle, debt_type);
      let coin_value_in_usd = usd_value(coin_price, debt_amount, decimals);
      total_value_usd = fixed_point32_empower::add(total_value_usd, coin_value_in_usd);
      i = i + 1;
    };
    total_value_usd
  }

  public fun debts_value_usd_with_weight(
    obligation: &Obligation,
    coin_decimals_registry: &CoinDecimalsRegistry,
    market: &Market,
    x_oracle: &XOracle,
  ): FixedPoint32 {
    let debt_types = obligation::debt_types(obligation);
    let total_weighted_value_usd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&debt_types));
    while( i < n ) {
      let debt_type = *vector::borrow(&debt_types, i);
      let interest_model = market_lib::interest_model(market, debt_type);
      let borrow_weight = interest_model_lib::borrow_weight(interest_model);
      let decimals = coin_decimals_registry::decimals(coin_decimals_registry, debt_type);
      let (debt_amount, _) = obligation::debt(obligation, debt_type);
      let coin_price = get_price(x_oracle, debt_type);
      let coin_value_usd = usd_value(coin_price, debt_amount, decimals);
      let weighted_value_usd = fixed_point32_empower::mul(coin_value_usd, borrow_weight);
      total_weighted_value_usd = fixed_point32_empower::add(total_weighted_value_usd, weighted_value_usd);
      i = i + 1;
    };
    total_weighted_value_usd
  }
}
