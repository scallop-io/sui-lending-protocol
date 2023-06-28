module scallop_liquidator::oracle {

  use sui::coin::Coin;
  use sui::sui::SUI;
  use sui::clock::Clock;

  use x_oracle::x_oracle::{Self, XOracle};
  use pyth::state::State as PythState;
  use pyth::price_info::PriceInfoObject;
  use wormhole::state::State as WormholeState;

  use pyth_rule::pyth_registry::PythRegistry;
  use pyth_rule::rule as pyth_rule_module;
  use sui::coin;
  use sui::tx_context::TxContext;

  use wormhole_usdc::coin::COIN as USDC;

  use scallop_liquidator::util;

  public fun update_usdc_sui_prices(
    x_oracle: &mut XOracle,
    wormhole_state: &WormholeState,
    pyth_state: &PythState,
    sui_price_info_object: &mut PriceInfoObject,
    usdc_price_info_object: &mut PriceInfoObject,
    pyth_registry: &PythRegistry,
    sui_vaa_buf: vector<u8>,
    usdc_vaa_buf: vector<u8>,
    fee: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    update_price<SUI>(
      x_oracle,
      wormhole_state,
      pyth_state,
      sui_price_info_object,
      pyth_registry,
      sui_vaa_buf,
      &mut fee,
      clock,
      ctx,
    );
    update_price<USDC>(
      x_oracle,
      wormhole_state,
      pyth_state,
      usdc_price_info_object,
      pyth_registry,
      usdc_vaa_buf,
      &mut fee,
      clock,
      ctx
    );
    util::destory_or_send_to_sender(fee, ctx);
  }

  public fun update_price<CoinType>(
    x_oracle: &mut XOracle,
    wormhole_state: &WormholeState,
    pyth_state: &PythState,
    price_info_object: &mut PriceInfoObject,
    pyth_registry: &PythRegistry,
    vaa_buf: vector<u8>,
    fee: &mut Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let real_fee = coin::split(fee, 1, ctx);
    let request = x_oracle::price_update_request<CoinType>(x_oracle);
    pyth_rule_module::set_price(
      &mut request,
      wormhole_state,
      pyth_state,
      price_info_object,
      pyth_registry,
      vaa_buf,
      real_fee,
      clock,
    );
    x_oracle::confirm_price_update_request(x_oracle, request, clock);
  }
}
