module scallop_liquidator::liquidator {

  use sui::clock::Clock;
  use sui::coin;
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

  use cetus_adaptor::cetus_flash_loan;
  use cetus_clmm::pool::{Pool as CetusPool, swap_pay_amount};
  use cetus_clmm::config::GlobalConfig as CetusConfig;

  use scallop_liquidator::price_util;
  use scallop_liquidator::coin_util;

  /// This function is used for Cetus Pool<A, B>
  /// where A = DebtType & B = CollateralType
  public fun liquidate_obligation_with_cetus_pool<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<DebtType, CollateralType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
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

    /// Make sure the liquidation is profitable
    let is_profitable = price_util::is_liquidation_profitable<CollateralType>(
      x_oracle,
      market,
      coin_decimals_registry,
      max_liq_amount,
      clock
    );
    if (is_profitable == false) { return };

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
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }

  /// This function is used for Cetus Pool<A, B>
  /// where A = CollateralType & B = DebtType
  public fun liquidate_obligation_with_reverse_cetus_pool<DebtType, CollateralType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<CollateralType, DebtType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
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

    /// Make sure the liquidation is profitable
    let is_profitable = price_util::is_liquidation_profitable<CollateralType>(
      x_oracle,
      market,
      coin_decimals_registry,
      max_liq_amount,
      clock
    );
    if (is_profitable == false) { return };

    /// Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
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
    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    /// Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    /// If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }
}
