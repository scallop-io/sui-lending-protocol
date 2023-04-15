module protocol::debt_value {
  
  use std::vector;
  use std::fixed_point32::FixedPoint32;
  use math::fixed_point32_empower;
  use protocol::obligation::{Self, Obligation};
  use protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  use protocol::interest_model as interest_model_lib;
  use protocol::market::{Self as market_lib, Market};
  use oracle::price_feed::{Self, PriceFeedHolder};
  
  public fun debts_value_usd(
    obligation: &Obligation,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    price_feeds: &PriceFeedHolder,
  ): FixedPoint32 {
    let debtTypes = obligation::debt_types(obligation);
    let totalValudInUsd = fixed_point32_empower::zero();
    let (i, n) = (0, vector::length(&debtTypes));
    while( i < n ) {
      let debtType = *vector::borrow(&debtTypes, i);
      let decimals = coin_decimals_registry::decimals(coinDecimalsRegsitry, debtType);
      let (debtAmount, _) = obligation::debt(obligation, debtType);
      let price_feed = price_feed::price_feed(price_feeds, debtType);
      let coin_value_in_usd = price_feed::calculate_coin_in_usd(price_feed, debtAmount, decimals);
      totalValudInUsd = fixed_point32_empower::add(totalValudInUsd, coin_value_in_usd);
      i = i + 1;
    };
    totalValudInUsd
  }

  public fun debts_value_usd_with_weight(
    obligation: &Obligation,
    coinDecimalsRegsitry: &CoinDecimalsRegistry,
    market: &Market,
    price_feeds: &PriceFeedHolder,
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
      let price_feed = price_feed::price_feed(price_feeds, debtType);
      let coin_value_in_usd = price_feed::calculate_coin_in_usd(price_feed, debtAmount, decimals);
      let weightedValueInUsd = fixed_point32_empower::mul(coin_value_in_usd, borrow_weight);
      totalValueInUsd = fixed_point32_empower::add(totalValueInUsd, weightedValueInUsd);
      i = i + 1;
    };
    totalValueInUsd
  }
}
