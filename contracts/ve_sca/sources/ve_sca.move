module ve_token::ve_sca {

  use std::type_name::{Self, TypeName};

  use sui::table::{Self, Table};
  use sui::balance::{Self, Balance, Supply};
  use sui::clock::{Self, Clock};
  use sui::object::{Self, UID};
  use sui::transfer;
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context::{Self, TxContext};

  const UnauthorizedIssuer: u64 = 0x1;

  friend ve_token::claim_ve_sca;

  struct VeScaAccessKey has drop {}

  struct VE_SCA has drop {}

  struct VeSca has key {
    id: UID,
    balance: Balance<VE_SCA>,
    mint_timestamp: u64,
    model: TypeName,
  }

  struct VeScaTreasury has key {
    id: UID,
    supply: Supply<VE_SCA>
  }

  struct VeScaState has key {
    id: UID,
    model_policies: Table<TypeName, TypeName>,
    issuers: VecSet<TypeName>,
  }

  struct VeScaCap has key, store {
    id: UID,
  }

  fun init(otw: VE_SCA, ctx: &mut TxContext) {
    let supply = balance::create_supply(otw);
    let ve_sca_treasury = VeScaTreasury {
      id: object::new(ctx),
      supply
    };
    let ve_sca_cap = VeScaCap {
      id: object::new(ctx),
    };
    let ve_sca_state = VeScaState {
      id: object::new(ctx),
      model_policies: table::new(ctx),
      issuers: vec_set::empty(),
    };
    
    let sender = tx_context::sender(ctx);

    transfer::transfer(ve_sca_cap, sender);
    transfer::share_object(ve_sca_state);
    transfer::share_object(ve_sca_treasury);
  }

  public fun balance(ve_sca: &VeSca): u64 { balance::value(&ve_sca.balance) }
  public fun model_policy(ve_sca_state: &VeScaState, key: TypeName): TypeName { *table::borrow(&ve_sca_state.model_policies, key) }
  public fun model(ve_sca: &VeSca): TypeName { ve_sca.model }

  public fun new_ve_sca<T: drop>(
    _issuer: T,
    ve_sca_state: &VeScaState,
    ve_sca_treasury: &mut VeScaTreasury,
    amount: u64,
    model: TypeName,
    clock: &Clock,
    ctx: &mut TxContext,
  ): VeSca {
    let issuer_type = type_name::get<T>();
    assert!(vec_set::contains(&ve_sca_state.issuers, &issuer_type), UnauthorizedIssuer);

    let ve_sca_balance = balance::increase_supply(&mut ve_sca_treasury.supply, amount);

    let timestamp = clock::timestamp_ms(clock) / 1000;
    let ve_sca = VeSca {
      id: object::new(ctx),
      balance: ve_sca_balance,
      mint_timestamp: timestamp,
      model: *table::borrow(&ve_sca_state.model_policies, model),
    };

    ve_sca
  }

  public fun add_issuer<T: drop>(
    _ve_sca_cap: &VeScaCap,
    ve_sca_state: &mut VeScaState,
  ) {
    vec_set::insert(&mut ve_sca_state.issuers, type_name::get<T>());
  }

  public fun remove_issuer<T: drop>(
    _ve_sca_cap: &VeScaCap,
    ve_sca_state: &mut VeScaState,
  ) {
    vec_set::remove(&mut ve_sca_state.issuers, &type_name::get<T>());
  }

  public(friend) fun redeem_ve_sca(
    ve_sca_treasury: &mut VeScaTreasury,
    ve_sca: VeSca,
  ) {
    let VeSca { 
      id,
      balance: balance,
      mint_timestamp: _,
      model: _,
    } = ve_sca;

    object::delete(id);

    balance::decrease_supply(&mut ve_sca_treasury.supply, balance);
    
    //@TODO: mint SCA here
    //@TODO: how to get amount of the redeemable SCA?
  }
}
