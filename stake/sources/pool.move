module stake::pool {
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use stake::calculator;
  use stake::admin::StakeAdminCap;
  
  friend stake::action;
  
  struct StakePool<phantom Wit, phantom StakeCoin, phantom Reward> has key, store {
    id: UID,
    totalStaked: Balance<StakeCoin>,
    rewardRatePerSec: u64,
    index: u64,
    indexStaked: u64,
    lastUpdated: u64
  }
  
  // Admin only
  public fun create_pool<Wit, StakeCoin, Reward>(
    _: &StakeAdminCap<Wit>,
    rewardRatePerSec: u64,
    indexStaked: u64,
    now: u64,
    ctx: &mut TxContext
  ): StakePool<Wit, StakeCoin, Reward> {
    StakePool<Wit, StakeCoin, Reward> {
      id: object::new(ctx),
      totalStaked: balance::zero(),
      rewardRatePerSec,
      index: 0,
      indexStaked,
      lastUpdated: now
    }
  }
  
  public fun index<Wit, StakeCoin, Reward>(
    self: &StakePool<Wit, StakeCoin, Reward>
  ): u64 {
    self.index
  }
  
  public fun index_staked<Wit, StakeCoin, Reward>(
    self: &StakePool<Wit, StakeCoin, Reward>
  ): u64 {
    self.indexStaked
  }
  
  public(friend) fun increase_staked<Wit, StakeCoin, Reward>(
    self: &mut StakePool<Wit, StakeCoin, Reward>,
    balanceToStake: Balance<StakeCoin>,
  ) {
    balance::join(&mut self.totalStaked, balanceToStake);
  }
  
  public(friend) fun decrease_staked<Wit, StakeCoin, Reward>(
    self: &mut StakePool<Wit, StakeCoin, Reward>,
    amount: u64,
  ): Balance<StakeCoin> {
    balance::split(&mut self.totalStaked, amount)
  }
  
  public(friend) fun accrue_reward<Wit, StakeCoin, Reward>(
    self: &mut StakePool<Wit, StakeCoin, Reward>,
    now: u64
  ) {
    let timeDelta = now - self.lastUpdated;
    self.index = calculator::calc_stake_index(
      self.index,
      self.indexStaked,
      balance::value(&self.totalStaked),
      self.rewardRatePerSec,
      timeDelta
    );
    // set lastupdated
    self.lastUpdated = now;
  }
}
