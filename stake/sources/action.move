module stake::action {
  
  use sui::coin::{Self, Coin};
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use stake::reward::{Self, StakeRewardTreasury};
  use stake::pool::{Self, StakePool, StakePools};
  use stake::check::{Self, StakeCheck};
  use x::wit_table::WitTable;
  use std::type_name::{TypeName, get};
  use x::balance_bag::BalanceBag;
  use x::balance_bag;
  use x::wit_table;
  
  friend stake::stake_sea;
  
  const EUnstakeTooMuch: u64 = 0;
  
  public(friend) fun stake<Wit, Reward, StakeCoin>(
    coin: Coin<StakeCoin>,
    stakePools: &mut WitTable<StakePools, TypeName, StakePool>,
    balanceBag: &mut BalanceBag,
    now: u64,
    ctx: &mut TxContext,
  ): StakeCheck<Wit, Reward, StakeCoin> {
    let stakeAmount = coin::value(&coin);
    // Always accrue reward for the pool
    pool::accrue_rewards(stakePools, now);
    // Add up the totalStaked
    pool::increase_staked<StakeCoin>(stakePools, coin::value(&coin));
    balance_bag::join(balanceBag, coin::into_balance(coin));
    
    // Issue the stake check
    let pool = wit_table::borrow(stakePools, get<StakeCoin>());
    check::new<Wit, Reward, StakeCoin>(stakeAmount, pool::index(pool), ctx)
  }
  
  public(friend) fun stake_more<Wit, Reward, StakeCoin>(
    coin: Coin<StakeCoin>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakePools: &mut WitTable<StakePools, TypeName, StakePool>,
    balanceBag: &mut BalanceBag,
    now: u64,
  ) {
    let newStakeAmount = coin::value(&coin);
    
    // Always accrue reward for the pool
    pool::accrue_rewards(stakePools, now);
    // accrue stake reward for user
    check::accrue_stake_reward(stakeCheck, stakePools);
    
    // Add up the totalStaked
    pool::increase_staked<StakeCoin>(stakePools, coin::value(&coin));
    balance_bag::join(balanceBag, coin::into_balance(coin));
    // Increase the stake amount for user
    check::increase_staked(stakeCheck, newStakeAmount);
  }
  
  public(friend) fun unstake<Wit, Reward, StakeCoin>(
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakePools: &mut WitTable<StakePools, TypeName, StakePool>,
    balanceBag: &mut BalanceBag,
    stakeRewardTreasury: &mut StakeRewardTreasury<Wit, Reward>,
    unstakeAmount: u64,
    now: u64,
  ): (Balance<StakeCoin>, Balance<Reward>) {
    assert!(check::staked(stakeCheck) >= unstakeAmount,  EUnstakeTooMuch);
    // Always accrue reward for the pool
    pool::accrue_rewards(stakePools, now);
    // Accrue stake reward for user
    check::accrue_stake_reward(stakeCheck, stakePools);
    
    // Withdraw the staked coin
    pool::decrease_staked<StakeCoin>(stakePools, unstakeAmount);
    let withdrawedBalance = balance_bag::split<StakeCoin>(balanceBag, unstakeAmount);
    check::decrease_staked(stakeCheck, unstakeAmount);
    // Claim the reward
    let rewardBalance = claim_reward(stakeCheck, stakeRewardTreasury);
    (withdrawedBalance, rewardBalance)
  }
  
  fun claim_reward<Wit, Reward, StakeCoin>(
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakeRewardTreasury: &mut StakeRewardTreasury<Wit, Reward>,
  ): Balance<Reward> {
    let rewardAmount = check::reward(stakeCheck);
    check::reset_reward(stakeCheck);
    reward::mint(stakeRewardTreasury, rewardAmount)
  }
}
