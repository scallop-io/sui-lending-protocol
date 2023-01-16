module stake::pool {
  
  use sui::tx_context::TxContext;
  use stake::calculator;
  use x::wit_table::WitTable;
  use std::type_name::{TypeName, get};
  use x::wit_table;
  use std::vector;
  
  friend stake::action;
  friend stake::stake_sea;
  
  struct StakePools has drop {}
  struct StakePool has copy, store {
    totalStaked: u64,
    rewardRatePerSec: u64,
    index: u64,
    indexStaked: u64,
    lastUpdated: u64
  }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<StakePools, TypeName, StakePool> {
    wit_table::new(StakePools{}, true, ctx)
  }
  
  public(friend) fun create_pool<StakeCoin>(
    pools: &mut WitTable<StakePools, TypeName, StakePool>,
    rewardRatePerSec: u64,
    indexStaked: u64,
    now: u64,
  ) {
    let stakePool = StakePool {
      totalStaked: 0,
      rewardRatePerSec,
      index: 0,
      indexStaked,
      lastUpdated: now
    };
    wit_table::add(StakePools{}, pools, get<StakeCoin>(), stakePool);
  }
  
  public fun index(pool: &StakePool): u64 { pool.index }
  public fun index_staked(pool: &StakePool): u64 { pool.indexStaked }
  
  public(friend) fun increase_staked<StakeCoin>(
    self: &mut WitTable<StakePools, TypeName, StakePool>,
    stakeAmount: u64,
  ) {
    let pool = wit_table::borrow_mut(StakePools{}, self, get<StakeCoin>());
    pool.totalStaked = pool.totalStaked + stakeAmount;
  }
  
  public(friend) fun decrease_staked<StakeCoin>(
    self: &mut WitTable<StakePools, TypeName, StakePool>,
    unStakeAmount: u64,
  ) {
    let pool = wit_table::borrow_mut(StakePools{}, self, get<StakeCoin>());
    pool.totalStaked = pool.totalStaked - unStakeAmount;
  }
  
  public(friend) fun accrue_rewards(
    self: &mut WitTable<StakePools, TypeName, StakePool>,
    now: u64
  ) {
    let types = wit_table::keys(self);
    let (i, n) = (0, vector::length(&types));
    while(i < n) {
      let type = *vector::borrow(&types, i);
      let pool = wit_table::borrow_mut(StakePools{}, self, type);
      let timeDelta = now - pool.lastUpdated;
      pool.index = calculator::calc_stake_index(
        pool.index,
        pool.indexStaked,
        pool.totalStaked,
        pool.rewardRatePerSec,
        timeDelta
      );
      // set lastupdated
      pool.lastUpdated = now;
      i = i + 1;
    };
  }
}
