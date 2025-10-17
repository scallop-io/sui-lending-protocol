#[deprecated]
module protocol::incentive_rewards {

  use std::type_name::{Self, TypeName};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
    
  friend protocol::app;
  friend protocol::market;

  struct RewardFactors has drop {}
    
  struct RewardFactor has store {
    coin_type: TypeName,
    reward_factor: FixedPoint32,
  }

  public fun reward_factor(self: &RewardFactor): FixedPoint32 { abort 0 } // deprecated
  
  // @NOTE: this function is deprecated, but since the struct of Market is already using it, we keep it here
  public(friend) fun init_table(ctx: &mut TxContext): WitTable<RewardFactors, TypeName, RewardFactor> {
    wit_table::new(RewardFactors {}, false, ctx)
  }
}