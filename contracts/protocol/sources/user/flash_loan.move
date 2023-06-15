module protocol::flash_loan {

  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::event::emit;
  use whitelist::whitelist;
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use protocol::error;
  use protocol::reserve::FlashLoan;

  struct BorrowFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
  }

  struct RepayFlashLoanEvent has copy, drop {
    borrower: address,
    asset: TypeName,
    amount: u64,
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

    emit(BorrowFlashLoanEvent {
      borrower: tx_context::sender(ctx),
      asset: type_name::get<T>(),
      amount,
    });

    market::borrow_flash_loan(market, amount, ctx)
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

    emit(RepayFlashLoanEvent {
      borrower: tx_context::sender(ctx),
      asset: type_name::get<T>(),
      amount: coin::value(&coin)
    });

    market::repay_flash_loan(market, coin, loan)
  }
}
