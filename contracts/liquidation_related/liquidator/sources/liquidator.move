module scallop_liquidator::liquidator {

  use sui::clock::Clock;
  use sui::coin::{Self, Coin};
  use sui::sui::SUI;
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use protocol::accrue_interest::accrue_interest_for_market_and_obligation;
  use protocol::liquidate::liquidate;
  use protocol::obligation::Obligation;
  use protocol::market::Market;
  use protocol::liquidation_evaluator::max_liquidation_amounts;
  use protocol::version::Version;

  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use x_oracle::x_oracle::XOracle;

  use pyth::state::State as PythState;
  use pyth::price_info::PriceInfoObject;
  use wormhole::state::State as WormholeState;
  use pyth_rule::pyth_registry::PythRegistry;

  use cetus_adaptor::cetus_flash_loan;
  use cetus_clmm::pool::{Pool as CetusPool, swap_pay_amount};
  use cetus_clmm::config::GlobalConfig as CetusConfig;

  use scallop_liquidator::oracle;
  use scallop_liquidator::util;

  public fun liquidate_obligation<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    wormhole_state: &WormholeState,
    pyth_state: &PythState,
    sui_price_info_object: &mut PriceInfoObject,
    usdc_price_info_object: &mut PriceInfoObject,
    pyth_registry: &PythRegistry,
    sui_vaa_buf: vector<u8>,
    usdc_vaa_buf: vector<u8>,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<DebtType, CollateralType>,
    fee: Coin<SUI>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    /// First update the oracle prices
    oracle::update_usdc_sui_prices(
      x_oracle,
      wormhole_state,
      pyth_state,
      sui_price_info_object,
      usdc_price_info_object,
      pyth_registry,
      sui_vaa_buf,
      usdc_vaa_buf,
      fee,
      clock,
      ctx
    );

    /// Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      market,
      obligation,
      clock,
    );

    /// Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    /// Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );

    /// Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<DebtType, CollateralType>(
      version,
      obligation,
      market,
      debt_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    /// Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);
    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);

    /// Repay to Cetus
    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    /// Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    /// If there is any debt coin left, send it to the liquidator
    util::destory_or_send_to_sender(debt_coin, ctx);
  }
}
