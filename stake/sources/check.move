module stake::check {
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use stake::pool::{Self, StakePool};
  use stake::calculator;
  
  friend stake::action;
  
  const ERedeemAmountNotMatch: u64 = 0;
  const ERedeemRewardAmountNotMatch: u64 = 1;
  
  struct StakeCheck<phantom Wit, phantom Reward, phantom StakeCoin> has key, store {
    id: UID,
    staked: u64,
    reward: u64,
    index: u64
  }
  
  public(friend) fun new<Wit, Reward, StakeCoin>(
    amount: u64, index: u64, ctx: &mut TxContext
  ): StakeCheck<Wit, Reward, StakeCoin> {
    StakeCheck {
      id: object::new(ctx),
      staked: amount,
      reward: 0,
      index
    }
  }
  
  public fun staked<Wit, Reward, StakeCoin>(
    self: &StakeCheck<Wit, Reward, StakeCoin>
  ): u64 {
    self.staked
  }
  
  public fun reward<Wit, StakeCoin, Reward>(
    self: &StakeCheck<Wit, StakeCoin, Reward>
  ): u64 {
    self.reward
  }
  
  public(friend) fun increase_staked<Wit, StakeCoin, Reward>(
    self: &mut StakeCheck<Wit, StakeCoin, Reward>, amount: u64
  ) {
    self.staked = self.staked + amount;
  }
  
  public(friend) fun decrease_staked<Wit, StakeCoin, Reward>(
    self: &mut StakeCheck<Wit, StakeCoin, Reward>, amount: u64
  ) {
    self.staked = self.staked - amount;
  }
  
  public(friend) fun reset_reward<Wit, StakeCoin, Reward>(
    self: &mut StakeCheck<Wit, StakeCoin, Reward>
  ) {
    self.reward = 0;
  }
  
  public(friend) fun accrue_stake_reward<Wit, Reward, StakeCoin>(
    self: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakePool: &StakePool<Wit, Reward, StakeCoin>,
  ) {
    let indexStaked = pool::index_staked(stakePool);
    let poolIndex = pool::index(stakePool);
    
    let newStakeReward = calculator::calc_stake_reward(
      self.staked,
      self.index,
      indexStaked,
      poolIndex
    );
    self.reward = self.reward + newStakeReward;
    // update the user's stake index to the latest
    self.index = pool::index(stakePool);
  }
}
