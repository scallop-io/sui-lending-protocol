module protocol::flash_loan {

  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::event::emit;
  use whitelist::whitelist;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::error;
  use protocol::reserve::{Self, FlashLoan};

  #[allow(unused_field)]
  struct BorrowFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
  }

  #[allow(unused_field)]
  struct RepayFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
  }

  struct BorrowFlashLoanV2Event has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
    fee: u64,
  }

  struct RepayFlashLoanV2Event has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
    fee: u64,
  }

  public fun borrow_flash_loan<T>(
    version: &Version,
    market: &mut Market,
    amount: u64,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    // check if version is supported
    version::assert_current_version(version);

    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );

    let coin_type = type_name::get<T>();
    // check if base asset is active
    assert!(
      market::is_base_asset_active(market, coin_type),
      error::base_asset_not_active_error()
    );

    let (coin, flash_loan) = market::borrow_flash_loan(market, amount, ctx);

    emit(BorrowFlashLoanV2Event {
      borrower: tx_context::sender(ctx),
      asset: coin_type,
      amount,
      fee: reserve::flash_loan_fee(&flash_loan),
    });

    (coin, flash_loan)
  }

  public fun repay_flash_loan<T>(
    version: &Version,
    market: &mut Market,
    coin: Coin<T>,
    loan: FlashLoan<T>,
    ctx: &mut TxContext
  ) {
    // check if version is supported
    version::assert_current_version(version);

    emit(RepayFlashLoanV2Event {
      borrower: tx_context::sender(ctx),
      asset: type_name::get<T>(),
      amount: coin::value(&coin),
      fee: reserve::flash_loan_fee(&loan),
    });

    market::repay_flash_loan(market, coin, loan)
  }
}
