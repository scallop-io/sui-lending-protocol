module test_coin::usdt {
  
  use sui::tx_context::TxContext;
  use sui::coin::{Self, TreasuryCap, Coin};
  use sui::url;
  use std::option;
  use sui::tx_context;
  use sui::math::pow;
  use sui::object::UID;
  use sui::transfer;
  use sui::object;
  
  struct USDT has drop {}
  
  struct Treasury has key {
    id: UID,
    cap: TreasuryCap<USDT>
  }
  
  fun init(wtiness: USDT, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"USDT";
    let name = b"USDT";
    let description = b"Test USDT";
    let icon_url = url::new_unsafe_from_bytes(
      b"https://mobius-fe.vercel.app/icons/tokens/usdt.svg"
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
    transfer::public_freeze_object(coinMeta)
  }
  
  public fun mint(treasury: &mut Treasury, ctx: &mut TxContext): Coin<USDT> {
    let amount = pow(10, 9 + 2);
    coin::mint(
      &mut treasury.cap,
      amount,
      ctx,
    )
  }
}
