// TODO: Add a coin for the protocol to incentivise user to lend and borrow on platform
module protocol::zq {
  
  use std::option;
  use sui::tx_context::TxContext;
  use sui::coin;
  use sui::url;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use sui::math;
  use sui::transfer;
  use sui::coin::TreasuryCap;
  
  struct ZQ has drop {}
  
  struct Treasury has key {
    id: UID,
    balance: Balance<ZQ>
  }
  
  struct TreasuryGuard has key {
    id: UID,
    treasuryCap: TreasuryCap<ZQ>
  }
  
  fun init(witness: ZQ, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"ZQ";
    let name = b"ZqCoin";
    let description = b"Test Bitcoin";
    let icon_url = url::new_unsafe_from_bytes(
      b"https://mobius-fe.vercel.app/icons/tokens/zq.svg"
    );
    let icon_url_option = option::some(icon_url);
    let (treasuryCap, coinMetadata) = coin::create_currency(
      witness, decimals, symbol, name, description, icon_url_option, ctx
    );
    // 21 million max supply
    let totalSupply = 21 * math::pow(10, decimals + 6);
    let treasury = Treasury {
      id: object::new(ctx),
      balance: coin::mint_balance(&mut treasuryCap, totalSupply)
    };
    transfer::share_object(treasury);
    // freeze the treasuryCap, so no one can mint more coins
    let treasuryGuard = TreasuryGuard {
      id: object::new(ctx),
      treasuryCap
    };
    transfer::freeze_object(treasuryGuard);
    transfer::freeze_object(coinMetadata);
  }
  
  public(friend) fun claim_(treasury: &mut Treasury, amount: u64): Balance<ZQ> {
    balance::split(&mut treasury.balance, amount)
  }
}
