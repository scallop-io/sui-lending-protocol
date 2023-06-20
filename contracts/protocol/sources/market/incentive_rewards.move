module protocol::incentive_rewards {

  use std::type_name::{Self, TypeName};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use math::fixed_point32_empower;
  use x::wit_table::{Self, WitTable};
    
  friend protocol::app;
  friend protocol::market;

  struct RewardRates has drop {}
    
  struct RewardRate has store {
    coin_type: TypeName,
    rate: FixedPoint32,
  }
  
  public(friend) fun init_table(ctx: &mut TxContext): WitTable<RewardRates, TypeName, RewardRate> {
    wit_table::new(RewardRates {}, false, ctx)
  }

  public(friend) fun set_reward_rate<T>(reward_rates: &mut WitTable<RewardRates, TypeName, RewardRate>, reward_rate_per_sec: u64, scale: u64) {
    let rate = fixed_point32::create_from_rational(reward_rate_per_sec, scale);
    let coin_type = type_name::get<T>();
    if (!wit_table::contains(reward_rates, coin_type)) {
      let reward_rate = RewardRate {
        coin_type,
        rate,
      };
      wit_table::add(RewardRates{}, reward_rates, coin_type, reward_rate);
    };
    
    let reward_rate = wit_table::borrow_mut(RewardRates{}, reward_rates, coin_type);
    reward_rate.rate = rate;
  }

  public fun calc_growth_rate(reward_rate: &RewardRate, time_delta: u64): FixedPoint32 {
    fixed_point32_empower::mul(reward_rate.rate, fixed_point32_empower::from_u64(time_delta))
  }
}