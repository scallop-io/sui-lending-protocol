module stake::pool {
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use stake::calculator;
  
  friend stake::action;
  friend stake::stake_sea;
  
  struct StakePool<phantom Wit, phantom Reward, phantom StakeCoin> has key, store {
    id: UID,
    totalStaked: Balance<StakeCoin>,
    rewardRatePerSec: u64,
    index: u64,
    indexStaked: u64,
    lastUpdated: u64
  }
  
  // Admin only
  public(friend) fun create_pool<Wit, Reward, StakeCoin>(
    rewardRatePerSec: u64,
    indexStaked: u64,
    now: u64,
    ctx: &mut TxContext
  ): StakePool<Wit, Reward, StakeCoin> {
    StakePool<Wit, Reward, StakeCoin> {
      id: object::new(ctx),
      totalStaked: balance::zero(),
      rewardRatePerSec,
      index: 0,
      indexStaked,
      lastUpdated: now
    }
  }
  
  public fun index<Wit, Reward, StakeCoin>(
    self: &StakePool<Wit, Reward, StakeCoin>
  ): u64 {
    self.index
  }
  
  public fun index_staked<Wit, Reward, StakeCoin>(
    self: &StakePool<Wit, Reward, StakeCoin>
  ): u64 {
    self.indexStaked
  }
  
  public(friend) fun increase_staked<Wit, Reward, StakeCoin>(
    self: &mut StakePool<Wit, Reward, StakeCoin>,
    balanceToStake: Balance<StakeCoin>,
  ) {
    balance::join(&mut self.totalStaked, balanceToStake);
  }
  
  public(friend) fun decrease_staked<Wit, Reward, StakeCoin>(
    self: &mut StakePool<Wit, Reward, StakeCoin>,
    amount: u64,
  ): Balance<StakeCoin> {
    balance::split(&mut self.totalStaked, amount)
  }
  
  public(friend) fun accrue_reward<Wit, Reward, StakeCoin>(
    self: &mut StakePool<Wit, Reward, StakeCoin>,
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
