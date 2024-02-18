/// this liquidator module is meant to be a helper of the liquidator
/// none of these functions are impacting the main logic of the core contract
/// these functions just a "bunch" of steps to do some actions to do liquidation
/// so the client side don't need to bother with a complex move call
module scallop_liquidator::liquidator {

  use std::vector;
  use std::type_name::get;
  use std::option;

  use sui::sui::SUI;
  use sui::clock::Clock;
  use sui::coin::{Self, TreasuryCap};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use sui_system::sui_system::SuiSystemState;
  use math::fixed_point32_empower;

  use protocol::accrue_interest::accrue_interest_for_market_and_obligation;
  use protocol::liquidate::liquidate;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::Market;
  use protocol::liquidation_evaluator::max_liquidation_amounts;
  use protocol::version::Version;
  use protocol::collateral_value::collaterals_value_usd_for_liquidation;
  use protocol::debt_value::debts_value_usd_with_weight;
  use protocol::flash_loan;

  use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
  use x_oracle::x_oracle::XOracle;

  use cetus_adaptor::cetus_flash_loan;
  use cetus_clmm::pool::{Pool as CetusPool, swap_pay_amount};
  use cetus_clmm::config::GlobalConfig as CetusConfig;

  use scallop_liquidator::coin_util;
  use scallop_liquidator::cetus_util;

  use amm::pool::Pool;
  use amm::swap;
  use amm::pool_registry::PoolRegistry;
  use protocol_fee_vault::vault::ProtocolFeeVault;
  use treasury::treasury::Treasury;
  use insurance_fund::insurance_fund::InsuranceFund;
  use afsui::afsui::AFSUI;
  use lsd::staked_sui_vault::{Self, StakedSuiVault};
  use referral_vault::referral_vault::ReferralVault as AmmReferralVault;
  use afsui_referral_vault::referral_vault::ReferralVault as AfSuiReferralVault;
  use safe::safe::Safe;
    
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

  public fun liquidate_obligation_same_assets<AssetType>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<AssetType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<AssetType>()) == false
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
    let (max_repay_amount, _max_liq_amount) = max_liquidation_amounts<AssetType, AssetType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    let (flash_loan_coin, flash_loan_receipt) = flash_loan::borrow_flash_loan(
      version,
      market,
      max_repay_amount,
      ctx
    );

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<AssetType, AssetType>(
      version,
      obligation,
      market,
      flash_loan_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    let repay_coin = coin::split(&mut collateral_coin, max_repay_amount, ctx);
    flash_loan::repay_flash_loan(
      version,
      market,
      repay_coin,
      flash_loan_receipt,
      ctx
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(collateral_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
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

  public fun liquidate_obligation_with_af_sui_as_debt_1<CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<X, SUI>,
    cetus_pool_for_collateral: &mut CetusPool<CollateralType, X>,
		af_staked_sui_vault: &mut StakedSuiVault,
		af_safe: &mut Safe<TreasuryCap<AFSUI>>,
		af_sui_referral_vault: &AfSuiReferralVault,
    validator_addr: address,
    sui_system_state: &mut SuiSystemState,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;
    let is_collateral_at_left = true;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<AFSUI>()) == false ||
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
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<AFSUI, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    let amount_of_sui = staked_sui_vault::afsui_to_sui(af_staked_sui_vault, af_safe, max_repay_amount);

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<X, SUI>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      amount_of_sui,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<CollateralType, X>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (sui_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool_for_debt,
      amount_of_sui,
      clock,
      ctx
    );

    let af_sui_coin = staked_sui_vault::request_stake(af_staked_sui_vault, af_safe, sui_system_state, af_sui_referral_vault, sui_coin, validator_addr, ctx);

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<AFSUI, CollateralType>(
      version,
      obligation,
      market,
      af_sui_coin,
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

  public fun liquidate_obligation_with_af_sui_as_debt_2<CollateralType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<X, SUI>,
    cetus_pool_for_collateral: &mut CetusPool<X, CollateralType>,
		af_staked_sui_vault: &mut StakedSuiVault,
		af_safe: &mut Safe<TreasuryCap<AFSUI>>,
		af_sui_referral_vault: &AfSuiReferralVault,
    validator_addr: address,
    sui_system_state: &mut SuiSystemState,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;
    let is_collateral_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<AFSUI>()) == false ||
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
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<AFSUI, CollateralType>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    let amount_of_sui = staked_sui_vault::afsui_to_sui(af_staked_sui_vault, af_safe, max_repay_amount);

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<X, SUI>(
      cetus_pool_for_debt,
      !is_debt_at_left,
      amount_of_sui,
    );
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<X, CollateralType>(
      cetus_pool_for_collateral,
      is_collateral_at_left,
      required_x_coin,
    );
    // Make sure the liquidation is profitable
    if (required_collateral_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (sui_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool_for_debt,
      amount_of_sui,
      clock,
      ctx
    );

    let af_sui_coin = staked_sui_vault::request_stake(af_staked_sui_vault, af_safe, sui_system_state, af_sui_referral_vault, sui_coin, validator_addr, ctx);

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<AFSUI, CollateralType>(
      version,
      obligation,
      market,
      af_sui_coin,
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

  public fun liquidate_obligation_with_af_sui_as_debt_and_usdc_as_collateral<USDC>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<USDC, SUI>,
		af_staked_sui_vault: &mut StakedSuiVault,
		af_safe: &mut Safe<TreasuryCap<AFSUI>>,
		af_sui_referral_vault: &AfSuiReferralVault,
    validator_addr: address,
    sui_system_state: &mut SuiSystemState,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<AFSUI>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<USDC>()) == false
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
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<AFSUI, USDC>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    let amount_of_sui = staked_sui_vault::afsui_to_sui(af_staked_sui_vault, af_safe, max_repay_amount);

    // Make sure the liquidation is profitable
    let required_x_coin = cetus_util::calculate_swap_amount_in<USDC, SUI>(
      cetus_pool,
      !is_debt_at_left,
      amount_of_sui,
    );

    // Make sure the liquidation is profitable
    if (required_x_coin > max_liq_amount) { return };

    // Borrow the DebtType Coin from Cetus
    let (sui_coin, loan_receipt) = cetus_flash_loan::borrow_b_repay_a_later(
      cetus_config,
      cetus_pool,
      amount_of_sui,
      clock,
      ctx
    );

    let af_sui_coin = staked_sui_vault::request_stake(af_staked_sui_vault, af_safe, sui_system_state, af_sui_referral_vault, sui_coin, validator_addr, ctx);

    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<AFSUI, USDC>(
      version,
      obligation,
      market,
      af_sui_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    // Split a coin from the collateral coin to repay the loan
    let loan_amount = swap_pay_amount(&loan_receipt);

    let repay_coin = coin::split(&mut collateral_coin, loan_amount, ctx);
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

  public fun liquidate_obligation_with_af_sui_as_collateral_1<L, DebtType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<X, DebtType>,
    cetus_pool_for_sui: &mut CetusPool<X, SUI>,
    af_pool: &mut Pool<L>,
    af_pool_registry: &PoolRegistry,
    af_protocol_fee_vault: &ProtocolFeeVault,
    af_treasury: &mut Treasury,
    af_insurance_fund: &mut InsuranceFund,
    af_amm_referral_vault: &AmmReferralVault,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = false;
    let is_collateral_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<AFSUI>()) == false
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
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, AFSUI>(
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
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<X, SUI>(
      cetus_pool_for_sui,
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
    let (debt_coin, collateral_coin) = liquidate<DebtType, AFSUI>(
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
      cetus_pool_for_sui,
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

    let sui_coin = swap::swap_exact_in(
      af_pool,
      af_pool_registry,
      af_protocol_fee_vault,
      af_treasury,
      af_insurance_fund,
      af_amm_referral_vault,
      collateral_coin,
      x_loan_amount,
      1_000_000_000_000_000_000 / 10, // 10%
      ctx,
    );

    let repay_for_x_coin = coin::split(&mut sui_coin, x_loan_amount, ctx);
    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_sui,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(sui_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }

  public fun liquidate_obligation_with_af_sui_as_collateral_2<L, DebtType, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool_for_debt: &mut CetusPool<DebtType, X>,
    cetus_pool_for_sui: &mut CetusPool<X, SUI>,
    af_pool: &mut Pool<L>,
    af_pool_registry: &PoolRegistry,
    af_protocol_fee_vault: &ProtocolFeeVault,
    af_treasury: &mut Treasury,
    af_insurance_fund: &mut InsuranceFund,
    af_amm_referral_vault: &AmmReferralVault,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let is_debt_at_left = true;
    let is_collateral_at_left = false;

    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<DebtType>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<AFSUI>()) == false
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
    let (max_repay_amount, max_liq_amount) = max_liquidation_amounts<DebtType, AFSUI>(
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
    let required_collateral_coin = cetus_util::calculate_swap_amount_in<X, SUI>(
      cetus_pool_for_sui,
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
    let (debt_coin, collateral_coin) = liquidate<DebtType, AFSUI>(
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
      cetus_pool_for_sui,
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

    let sui_coin = swap::swap_exact_in(
      af_pool,
      af_pool_registry,
      af_protocol_fee_vault,
      af_treasury,
      af_insurance_fund,
      af_amm_referral_vault,
      collateral_coin,
      x_loan_amount,
      1_000_000_000_000_000_000 / 10, // 10%
      ctx,
    );

    let repay_for_x_coin = coin::split(&mut sui_coin, x_loan_amount, ctx);
    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool_for_sui,
      repay_for_x_coin,
      x_loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(sui_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
    coin_util::destory_or_send_to_sender(x_coin, ctx);
  }

  public fun liquidate_obligation_with_af_sui_as_collateral_and_usdc_as_debt<L, X>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin_decimals_registry: &CoinDecimalsRegistry,
    x_oracle: &mut XOracle,
    cetus_config:  &CetusConfig,
    cetus_pool: &mut CetusPool<X, SUI>,
    af_pool: &mut Pool<L>,
    af_pool_registry: &PoolRegistry,
    af_protocol_fee_vault: &ProtocolFeeVault,
    af_treasury: &mut Treasury,
    af_insurance_fund: &mut InsuranceFund,
    af_amm_referral_vault: &AmmReferralVault,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    // Make sure the obligation has DebtType, and CollateralType
    if (
      vector::contains(&obligation::debt_types(obligation), &get<X>()) == false ||
        vector::contains(&obligation::collateral_types(obligation), &get<AFSUI>()) == false
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
    let (max_repay_amount, _max_liq_amount) = max_liquidation_amounts<X, AFSUI>(
      obligation,
      market,
      coin_decimals_registry,
      x_oracle,
      clock
    );

    // Borrow the DebtType Coin from Cetus
    let (debt_coin, loan_receipt) = cetus_flash_loan::borrow_a_repay_b_later(
      cetus_config,
      cetus_pool,
      max_repay_amount,
      clock,
      ctx
    );
    
    // Liquidate the obligation
    let (debt_coin, collateral_coin) = liquidate<X, AFSUI>(
      version,
      obligation,
      market,
      debt_coin,
      coin_decimals_registry,
      x_oracle,
      clock,
      ctx
    );

    let loan_amount = swap_pay_amount(&loan_receipt);

    let sui_coin = swap::swap_exact_in(
      af_pool,
      af_pool_registry,
      af_protocol_fee_vault,
      af_treasury,
      af_insurance_fund,
      af_amm_referral_vault,
      collateral_coin,
      loan_amount,
      1_000_000_000_000_000_000 / 2, // 1 / 2 = 50%
      ctx,
    );

    let repay_coin = coin::split(&mut sui_coin, loan_amount, ctx);  

    cetus_flash_loan::repay_b(
      cetus_config,
      cetus_pool,
      repay_coin,
      loan_receipt,
    );

    // Send the collateral coin to the liquidator
    transfer::public_transfer(sui_coin, tx_context::sender(ctx));

    // If there is any debt coin left, send it to the liquidator
    coin_util::destory_or_send_to_sender(debt_coin, ctx);
  }
}