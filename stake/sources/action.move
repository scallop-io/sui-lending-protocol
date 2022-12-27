module stake::action {
  
  use sui::coin::{Self, Coin};
  use sui::tx_context::TxContext;
  use stake::reward::{Self, StakeRewardTreasury};
  use stake::pool::{Self, StakePool};
  use stake::check::{Self, StakeCheck};
  use sui::balance::Balance;
  
  const EUnstakeTooMuch: u64 = 0;
  
  public fun stake<Wit, Reward, StakeCoin>(
    coin: Coin<StakeCoin>,
    stakePool: &mut StakePool<Wit, Reward, StakeCoin>,
    now: u64,
    ctx: &mut TxContext,
  ): StakeCheck<Wit, Reward, StakeCoin> {
    let stakeAmount = coin::value(&coin);
    // Always accrue reward for the pool
    pool::accrue_reward(stakePool, now);
    // Add up the totalStaked
    pool::increase_staked(stakePool, coin::into_balance(coin));
    
    // Issue the stake check
    check::new<Wit, Reward, StakeCoin>(stakeAmount, pool::index(stakePool), ctx)
  }
  
  public fun stake_more<Wit, Reward, StakeCoin>(
    coin: Coin<StakeCoin>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakePool: &mut StakePool<Wit, Reward, StakeCoin>,
    now: u64,
  ) {
    let newStakeAmount = coin::value(&coin);
    
    // Always accrue reward for the pool
    pool::accrue_reward(stakePool, now);
    // accrue stake reward for user
    check::accrue_stake_reward(stakeCheck, stakePool);
    
    // Add up the totalStaked
    pool::increase_staked(stakePool, coin::into_balance(coin));
    // Increase the stake amount for user
    check::increase_staked(stakeCheck, newStakeAmount);
  }
  
  public fun unstake<Wit, Reward, StakeCoin>(
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    stakePool: &mut StakePool<Wit, Reward, StakeCoin>,
    stakeRewardTreasury: &mut StakeRewardTreasury<Wit, Reward>,
    unstakeAmount: u64,
    now: u64,
  ): (Balance<StakeCoin>, Balance<Reward>) {
    assert!(check::staked(stakeCheck) >= unstakeAmount,  EUnstakeTooMuch);
    // Always accrue reward for the pool
    pool::accrue_reward(stakePool, now);
    // Accrue stake reward for user
    check::accrue_stake_reward(stakeCheck, stakePool);
    
    // Withdraw the staked coin
    let withdrawedBalance = pool::decrease_staked(stakePool, unstakeAmount);
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
