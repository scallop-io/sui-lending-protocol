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

  public fun reward_factor(self: &RewardFactor): FixedPoint32 { self.reward_factor }
  
  public(friend) fun init_table(ctx: &mut TxContext): WitTable<RewardFactors, TypeName, RewardFactor> {
    wit_table::new(RewardFactors {}, false, ctx)
  }

  public(friend) fun set_reward_factor<T>(reward_factors: &mut WitTable<RewardFactors, TypeName, RewardFactor>, reward_factor: u64, scale: u64) {
    let factor = fixed_point32::create_from_rational(reward_factor, scale);
    let coin_type = type_name::get<T>();
    if (!wit_table::contains(reward_factors, coin_type)) {
      let reward_factor = RewardFactor {
        coin_type,
        reward_factor: factor,
      };
      wit_table::add(RewardFactors{}, reward_factors, coin_type, reward_factor);
    };
    
    let reward_factor = wit_table::borrow_mut(RewardFactors{}, reward_factors, coin_type);
    reward_factor.reward_factor = factor;
  }
}