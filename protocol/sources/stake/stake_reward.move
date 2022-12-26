module protocol::stake_reward {
  use sui::object::{Self, UID};
  use sui::balance::Supply;
  use sui::tx_context::TxContext;
  use std::option;
  use sui::url;
  use sui::coin;
  use sui::transfer;
  
  friend protocol::stake;
  
  struct STAKE_REWARD has drop {}
  
  struct StakeRewardTreasury has key {
    id: UID,
    supply: Supply<STAKE_REWARD>
  }
  
  fun init(witness: STAKE_REWARD, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"STW";
    let name = b"StakeReword";
    let description = b"Stake reword";
    let icon_url = url::new_unsafe_from_bytes(
      b"https://mobius-fe.vercel.app/icons/tokens/zq.svg"
    );
    let icon_url_option = option::some(icon_url);
    let (treasuryCap, coinMetadata) = coin::create_currency(
      witness, decimals, symbol, name, description, icon_url_option, ctx
    );
    let treasury = StakeRewardTreasury {
      id: object::new(ctx),
      supply: coin::treasury_into_supply(treasuryCap)
    };
    transfer::share_object(treasury);
    transfer::freeze_object(coinMetadata);
  }
}
