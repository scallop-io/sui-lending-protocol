module ve_token::ve_sca {

  use sui::balance::{Self, Balance, Supply};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID};
  use sui::transfer;
  use sui::tx_context::TxContext;

  struct VE_SCA has drop {}

  struct VeSca has key {
    id: UID,
    balance: Balance<VE_SCA>,
    mint_timestamp: u64
  }

  struct VeScaTreasury has key {
    id: UID,
    supply: Supply<VE_SCA>
  }

  fun init(otw: VE_SCA, ctx: &mut TxContext) {
    let supply = balance::create_supply(otw);
    let ve_sca_treasury = VeScaTreasury {
      id: object::new(ctx),
      supply
    };
    transfer::share_object(ve_sca_treasury);
  }

  public fun mint_ve_sca(
    ve_sca_treasury: &mut VeScaTreasury,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext
  ): VeSca {
    let ve_sca_balance = balance::increase_supply(&mut ve_sca_treasury.supply, amount);
    let timestamp = clock::timestamp_ms(clock) / 1000;
    let ve_sca = VeSca {
      id: object::new(ctx),
      balance: ve_sca_balance,
      mint_timestamp: timestamp
    };
    ve_sca
  }
}
