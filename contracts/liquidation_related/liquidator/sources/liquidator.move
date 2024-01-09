/// this liquidator module is meant to be a helper of the liquidator
/// none of these functions are impacting the main logic of the core contract
/// these functions just a "bunch" of steps to do some actions to do liquidation
/// so the client side don't need to bother with a complex move call
module scallop_liquidator::liquidator {

  use std::vector;
  use std::type_name::get;
  use std::option;

  use sui::clock::Clock;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use math::fixed_point32_empower;

  use protocol::accrue_interest::accrue_interest_for_market_and_obligation;
  use protocol::liquidate::liquidate;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::Market;
  use protocol::liquidation_evaluator::max_liquidation_amounts;
  use protocol::version::Version;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::debt_value::debts_value_usd_with_weight;

  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use x_oracle::x_oracle::XOracle;

  use cetus_adaptor::cetus_flash_loan;
  use cetus_clmm::pool::{Pool as CetusPool, swap_pay_amount};
  use cetus_clmm::config::GlobalConfig as CetusConfig;

  use scallop_liquidator::coin_util;
  use scallop_liquidator::cetus_util;

  use borrow_incentive::user;
  use borrow_incentive::incentive_account::IncentiveAccounts;
  use borrow_incentive::incentive_pool::IncentivePools;

  public fun is_eligible_to_be_liquidated(
    obligation: &Obligation,
    market: &Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &XOracle,
    clock: &Clock,
  ): bool {
    // calculate the value of collaterals and debts for liquidation
    let collaterals_value = collaterals_value_usd_for_liquidation(obligation, market, coin_decimals_registry, x_oracle, clock);
    let weighted_debts_value = debts_value_usd_with_weight(obligation, coin_decimals_registry, market, x_oracle, clock);
    
    fixed_point32_empower::gt(weighted_debts_value, collaterals_value)
  }

  public fun force_unstake_if_unhealthy<RewardType>(
    incentive_pools: &mut IncentivePools<RewardType>,
    incentive_accounts: &mut IncentiveAccounts,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;    

    if (option::is_none(&obligation::lock_key(obligation)))
      return;
    
    user::force_unstake_unhealthy<RewardType>(
      incentive_pools,
      incentive_accounts,
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );
  }

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
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;    
    
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
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

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
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

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
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

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

  public fun liquidate_obligation_with_cetus_pool_cross_1<DebtType, CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<DebtType, X>,
    cetus_pool_for_collateral: &mut CetusPool<CollateralType, X>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // define whether a particular coin type at left of right of the generic type
    // although these value won't change, it's still necessary to give it a name
    let is_debt_at_left = true;
    let is_collateral_at_left = true;

    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<DebtType, X>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      max_repay_amount,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<CollateralType, X>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
        cetus_config,
        cetus_pool_for_debt,
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

    // borrow coin of type that against the collateral coin
    let (x_coin, x_loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
        cetus_config,
        cetus_pool_for_collateral,
        loan_amount,
        clock,
        ctx
      );

    let repay_coin = coin::split(&mut x_coin, loan_amount, ctx);

    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_debt,
      repay_coin,
      loan_receipt,
    );

    let x_loan_amount = swap_pay_amount(&x_loan_receipt);
    let repay_for_x_coin = coin::split(&mut collateral_coin, x_loan_amount, ctx);

    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool_for_collateral,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }

  public fun liquidate_obligation_with_cetus_pool_cross_2<DebtType, CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<DebtType, X>,
    cetus_pool_for_collateral: &mut CetusPool<X, CollateralType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = true;
    let is_collateral_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<DebtType, X>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      max_repay_amount,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<X, CollateralType>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool_for_debt,
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

    // borrow coin of type that against the collateral coin
    let (x_coin, x_loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool_for_collateral,
      loan_amount,
      clock,
      ctx
    );

    let repay_coin = coin::split(&mut x_coin, loan_amount, ctx);

    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_debt,
      repay_coin,
      loan_receipt,
    );

    let x_loan_amount = swap_pay_amount(&x_loan_receipt);
    let repay_for_x_coin = coin::split(&mut collateral_coin, x_loan_amount, ctx);

    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_collateral,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }

  public fun liquidate_obligation_with_cetus_pool_cross_3<DebtType, CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<X, DebtType>,
    cetus_pool_for_collateral: &mut CetusPool<CollateralType, X>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;
    let is_collateral_at_left = true;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<X, DebtType>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      max_repay_amount,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<CollateralType, X>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool_for_debt,
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

    // borrow coin of type that against the collateral coin
    let (x_coin, x_loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool_for_collateral,
      loan_amount,
      clock,
      ctx
    );

    let repay_coin = coin::split(&mut x_coin, loan_amount, ctx);

    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool_for_debt,
      repay_coin,
      loan_receipt,
    );

    let x_loan_amount = swap_pay_amount(&x_loan_receipt);
    let repay_for_x_coin = coin::split(&mut collateral_coin, x_loan_amount, ctx);

    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool_for_collateral,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }

  public fun liquidate_obligation_with_cetus_pool_cross_4<DebtType, CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<X, DebtType>,
    cetus_pool_for_collateral: &mut CetusPool<X, CollateralType>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;
    let is_collateral_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<CollateralType>()) == false
    ) return;

    // Then accrue interest for the obligation
    accrue_interest_for_market_and_obligation(
      version,
      market,
      obligation,
      clock,
    );

    if (!is_eligible_to_be_liquidated(obligation, market, coin_decimals_registry, x_oracle, clock))
      return;

    // Calculate the liquidation amount
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<X, DebtType>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      max_repay_amount,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<X, CollateralType>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool_for_debt,
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

    // borrow coin of type that against the collateral coin
    let (x_coin, x_loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool_for_collateral,
      loan_amount,
      clock,
      ctx
    );

    let repay_coin = coin::split(&mut x_coin, loan_amount, ctx);

    cetus_flash_loan::repay_a(
      cetus_config,
      cetus_pool_for_debt,
      repay_coin,
      loan_receipt,
    );

    let x_loan_amount = swap_pay_amount(&x_loan_receipt);
    let repay_for_x_coin = coin::split(&mut collateral_coin, x_loan_amount, ctx);

    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_collateral,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }
}