module test_coin::usdc {
  
  use sui::tx_context::TxContext;
  use sui::coin::{Self, TreasuryCap, Coin};
  use std::option;
  use sui::tx_context;
  use sui::math::pow;
  use sui::object::UID;
  use sui::transfer;
  use sui::object;
  
  struct USDC has drop {}
  
  struct Treasury has key {
    id: UID,
    cap: TreasuryCap<USDC>
  }
  
  fun init(wtiness: USDC, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"USDC";
    let name = b"USDC";
    let description = b"Test USDC";
    let icon_url_option = option::none();
    let (treasuryCap, coinMeta) = coin::create_currency(
      wtiness,
      decimals,
      symbol,
      name,
      description,
      icon_url_option,
      ctx
    );
    let sender = tx_context::sender(ctx);
    coin::mint_and_transfer(
      &mut treasuryCap,
      pow(10, decimals + 3),
      sender,
      ctx
    );
    transfer::share_object(
      Treasury { id: object::new(ctx), cap: treasuryCap }
    );
    transfer::public_freeze_object(coinMeta)
  }
  
  public fun mint(treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<USDC> {
    coin::mint(
      &mut treasury.cap,
      amount,
      ctx,
    )
  }
}
