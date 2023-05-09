module test_coin::btc {
  
  use sui::tx_context::TxContext;
  use sui::coin::{Self, TreasuryCap, Coin};
  use std::option;
  use sui::tx_context;
  use sui::math::pow;
  use sui::object::UID;
  use sui::transfer;
  use sui::object;
  
  struct BTC has drop {}
  
  struct Treasury has key {
    id: UID,
    cap: TreasuryCap<BTC>
  }
  
  fun init(wtiness: BTC, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"BTC";
    let name = b"BTC";
    let description = b"Test Bitcoin";
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
      pow(10, decimals),
      sender,
      ctx
    );
    transfer::share_object(
      Treasury { id: object::new(ctx), cap: treasuryCap }
    );
    transfer::public_freeze_object(coinMeta)
  }
  
  public fun mint(treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): Coin<BTC> {
    coin::mint(
      &mut treasury.cap,
      amount,
      ctx,
    )
  }
}
