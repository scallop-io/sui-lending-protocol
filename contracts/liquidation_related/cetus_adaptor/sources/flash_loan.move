module cetus_adaptor::cetus_flash_loan {

  use sui::clock::Clock;
  use sui::balance;
  use sui::tx_context::TxContext;
  use sui::coin::{Self, Coin};

  use cetus_clmm::pool::{flash_swap, repay_flash_swap, swap_pay_amount, FlashSwapReceipt, Pool};
  use cetus_clmm::config::GlobalConfig;

  const CETUS_MIN_PRICE_LIMIT: u128 = 4295048016;
  const CETUS_MAX_PRICE_LIMIT: u128 = 79226673515401279992447579055;

  const ERepayAmountIncorrect: u64 = 333;
  const ERepayTypeIncorrect: u64 = 334;

  /// This function is used to borrow B from Cetus Pool<A, B> and repay A later
  /// For example: borrow SUI from Cetus Pool<USDC, SUI> and repay USDC later
  public fun borrow_b_repay_a_later<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<B>, FlashSwapReceipt<A, B>) {
    /// We want to borrow B
    /// so we need to swap A to B, hence a2b = true
    let a2b = true;

    /// we want to specify the exact amount of B we want to borrow
    /// "by_amount_in = true": means the amount will be the input amount of A
    /// "by_amount_in = false", means the amount will be the output amount of B
    ///  so we set by_amount_in = false
    let by_amount_in = false;

    /// For Cetus Pool<A, B>, A is base token, B is quote token
    /// As we swap from A to B, it means the base token price will drop
    /// so we need to set the price limit to be the minimum price limit to allow maximum borrow of B
    let sqrt_price_limit = CETUS_MIN_PRICE_LIMIT;

    let (a_balance, b_balance, receipt) = flash_swap(
      cetus_config,
      cetus_pool,
      a2b,
      by_amount_in,
      amount,
      sqrt_price_limit,
      clock
    );

    /// destroy the zero balance
    balance::destroy_zero(a_balance);

    /// return the B coin and the receipt
    (
      coin::from_balance(b_balance, ctx),
      receipt
    )
  }


  /// This function is used to borrow A from Cetus Pool<A, B> and repay B later
  /// For example: borrow USDC from Cetus Pool<USDC, SUI> and repay SUI later
  public fun borrow_a_repay_b_later<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<A>, FlashSwapReceipt<A, B>) {
    /// We want to borrow A
    /// so we need to swap B to A, hence a2b = false
    let a2b = false;

    /// we want to specify the exact amount of A we want to borrow
    /// "by_amount_in = true": means the amount will be the input amount of B
    /// "by_amount_in = false", means the amount will be the output amount of A
    ///  so we set by_amount_in = false
    let by_amount_in = false;

    /// For Cetus Pool<A, B>, A is base token, B is quote token
    /// As we swap from B to A, it means the base token price will rise
    /// so we need to set the price limit to be the maximum price limit to allow maximum borrow of A
    let sqrt_price_limit = CETUS_MAX_PRICE_LIMIT;

    let (a_balance, b_balance, receipt) = flash_swap(
      cetus_config,
      cetus_pool,
      a2b,
      by_amount_in,
      amount,
      sqrt_price_limit,
      clock
    );

    /// destroy the zero balance
    balance::destroy_zero(b_balance);

    /// return the A coin and the receipt
    (
      coin::from_balance(a_balance, ctx),
      receipt
    )
  }


  /// This function is used to borrow B from Cetus Pool<A, B> and repay B later
  /// For example: borrow SUI from Cetus Pool<USDC, SUI> and repay SUI later
  public fun borrow_b_repay_b_later<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<B>, FlashSwapReceipt<A, B>) {
    /// First we borrow B from Cetus Pool<A, B>
    let (b_coin, a_receipt) = borrow_b_repay_a_later(
      cetus_config,
      cetus_pool,
      amount,
      clock,
      ctx
    );
    /// Then we borrow A from Cetus Pool<A, B>
    let (a_coin, b_receipt) = borrow_a_repay_b_later(
      cetus_config,
      cetus_pool,
      swap_pay_amount(&a_receipt),
      clock,
      ctx
    );
    /// Repay A to Cetus Pool<A, B>
    repay_a(
      cetus_config,
      cetus_pool,
      a_coin,
      a_receipt
    );
    /// Return B coin and the receipt
    ( b_coin, b_receipt )
  }

  /// This function is used to borrow A from Cetus Pool<A, B> and repay A later
  /// For example: borrow USDC from Cetus Pool<USDC, SUI> and repay USDC later
  public fun borrow_a_repay_a_later<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): (Coin<A>, FlashSwapReceipt<A, B>) {
    /// First we borrow A from Cetus Pool<A, B>
    let (a_coin, b_receipt) = borrow_a_repay_b_later(
      cetus_config,
      cetus_pool,
      amount,
      clock,
      ctx
    );
    /// Then we borrow B from Cetus Pool<A, B>
    let (b_coin, a_receipt) = borrow_b_repay_a_later(
      cetus_config,
      cetus_pool,
      swap_pay_amount(&b_receipt),
      clock,
      ctx
    );
    /// Repay B to Cetus Pool<A, B>
    repay_b(
      cetus_config,
      cetus_pool,
      b_coin,
      b_receipt
    );
    /// Return A coin and the receipt
    ( a_coin, a_receipt )
  }


  public fun repay_b<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    b_coin: Coin<B>,
    receipt: FlashSwapReceipt<A, B>,
  ) {
    // Make sure we repay the correct amount
    assert!(swap_pay_amount(&receipt) == coin::value(&b_coin), ERepayAmountIncorrect);

    repay_flash_swap(
      cetus_config,
      cetus_pool,
      balance::zero(),
      coin::into_balance(b_coin),
      receipt
    );
  }


  public fun repay_a<A, B>(
    cetus_config: &GlobalConfig,
    cetus_pool: &mut Pool<A, B>,
    a_coin: Coin<A>,
    receipt: FlashSwapReceipt<A, B>,
  ) {
    // Make sure we repay the correct amount
    assert!(swap_pay_amount(&receipt) == coin::value(&a_coin), ERepayAmountIncorrect);

    repay_flash_swap(
      cetus_config,
      cetus_pool,
      coin::into_balance(a_coin),
      balance::zero(),
      receipt
    );
  }
}
