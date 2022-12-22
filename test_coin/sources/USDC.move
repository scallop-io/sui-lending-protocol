module test_coin::usdc {
  
  use sui::tx_context::TxContext;
  use sui::coin::{Self, TreasuryCap};
  use sui::url;
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
    let icon_url = url::new_unsafe_from_bytes(
      b"https://mobius-fe.vercel.app/icons/tokens/usdc.svg"
    );
    let icon_url_option = option::some(icon_url);
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
      pow(10, decimals + 8),
      sender,
      ctx
    );
    transfer::share_object(
      Treasury { id: object::new(ctx), cap: treasuryCap }
    );
    transfer::freeze_object(coinMeta)
  }
  
  public entry fun mint(treasury: &mut Treasury, ctx: &mut TxContext) {
    let amount = pow(10, 9 + 2);
    coin::mint_and_transfer(
      &mut treasury.cap,
      amount,
      tx_context::sender(ctx),
      ctx,
    );
  }
}
