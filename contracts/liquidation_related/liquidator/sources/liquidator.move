module scallop_liquidator::liquidator {

  use std::vector;
  use std::type_name::get;
  use std::fixed_point32;

  use sui::clock::Clock;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use protocol::accrue_interest::accrue_interest_for_market_and_obligation;
  use protocol::liquidate::liquidate;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::Market;
  use protocol::liquidation_evaluator::max_liquidation_amounts;
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::version::Version;

  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use x_oracle::x_oracle::XOracle;

  use cetus_adaptor::cetus_flash_loan;
  use cetus_clmm::pool::{Pool as CetusPool, swap_pay_amount};
  use cetus_clmm::config::GlobalConfig as CetusConfig;

  use scallop_liquidator::coin_util;
  use scallop_liquidator::cetus_util;

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
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      market,
      obligation,
      clock,
    );

    // to avoid the transaction failed, because the passed obligation that is not liquidatable
    // we need to check it in advance
    // the purpose of avoiding the transaction fails is to do batch liquidation
    if (!is_liquidatable(market, coin_decimals_registry, x_oracle, obligation, clock)) { return };

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let is_profitable = cetus_util::is_liquidation_profitable(
      cetus_pool,
      false,
      max_repay_amount,
      max_liq_amount,
    );
    if (is_profitable == false) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );

    // Liquidate the obligation
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

    // Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);
    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);

    // Repay to Cetus
    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
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
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      market,
      obligation,
      clock,
    );

    // to avoid the transaction failed, because the passed obligation that is not liquidatable
    // we need to check it in advance
    // the purpose of avoiding the transaction fails is to do batch liquidation
    if (!is_liquidatable(market, coin_decimals_registry, x_oracle, obligation, clock)) { return };

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let is_profitable = cetus_util::is_liquidation_profitable(
      cetus_pool,
      true,
      max_repay_amount,
      max_liq_amount,
    );
    if (is_profitable == false) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );

    // Liquidate the obligation
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

    // Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);
    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);

    // Repay to Cetus
    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }

  /// This function is used for Cetus Pool<A, B>
  /// where A = CollateralType = DebtType
  public fun liquidate_obligation_with_cetus_pool_only_a<DebtType, B>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<DebtType, B>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<DebtType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      market,
      obligation,
      clock,
    );

    // to avoid the transaction failed, because the passed obligation that is not liquidatable
    // we need to check it in advance
    // the purpose of avoiding the transaction fails is to do batch liquidation
    if (!is_liquidatable(market, coin_decimals_registry, x_oracle, obligation, clock)) { return };

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, DebtType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let is_profitable = cetus_util::is_liquidation_profitable_with_double_swap(
      cetus_pool,
      max_repay_amount,
      max_liq_amount,
    );
    if (is_profitable == false) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_a_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<DebtType, DebtType>(
      version,
      obligation,
      market,
      debt_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    // Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);
    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);

    // Repay to Cetus
    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }

  /// This function is used for Cetus Pool<A, B>
  /// where B = CollateralType = DebtType
  public fun liquidate_obligation_with_cetus_pool_only_b<A, DebtType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<A, DebtType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<DebtType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      market,
      obligation,
      clock,
    );

    // to avoid the transaction failed, because the passed obligation that is not liquidatable
    // we need to check it in advance
    // the purpose of avoiding the transaction fails is to do batch liquidation
    if (!is_liquidatable(market, coin_decimals_registry, x_oracle, obligation, clock)) { return };

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, DebtType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let is_profitable = cetus_util::is_liquidation_profitable_with_double_swap(
      cetus_pool,
      max_repay_amount,
      max_liq_amount,
    );
    if (is_profitable == false) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_b_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<DebtType, DebtType>(
      version,
      obligation,
      market,
      debt_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    // Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);
    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);

    // Repay to Cetus
    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }

  public fun is_liquidatable(
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    obligation: &Obligation,
    clock: &Clock,
  ): bool {
    let collaterals_value = collaterals_value_usd_for_liquidation(obligation, market, coin_decimals_registry, x_oracle, clock);
    let weighted_debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);

    let collateral_raw_value = fixed_point32::get_raw_value(collaterals_value);
    let debt_raw_value = fixed_point32::get_raw_value(weighted_debts_value);
    debt_raw_value > collateral_raw_value
  }
}
