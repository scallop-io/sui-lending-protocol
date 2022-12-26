// Put all reward calculating logic here
module stake::calculator {
  
  use math::exponential;
  
  /**
   * @notice Calculate the new index for a StakePool
   * @param prevIndex : Previous index of the StakePool
   * @param indexStaked : Staked amount of the index
   * @param rewardRatePerSec: Rewards distributed to the StakePool per second
   * @param totalStaked : Total staked amount of the StakePool
   * @returns timeDelta : Seconds passed since the previous stake index generated
   */
  public fun calc_stake_index(
    prevIndex: u64,
    indexStaked: u64,
    totalStaked: u64,
    rewardRatePerSec: u64,
    timeDelta: u64,
  ): u64 {
    /********
      totalNewRewards = rewardRatePerSec * timeDelta
      newIndexReward = (indexStaked / totalStaked) * totalNewRewards
      newIndex = prevIndex + newIndexReward
    *********/
    let totalNewRewards = (rewardRatePerSec * timeDelta as u128);
    let newIndexReward = exponential::mul_scalar_exp_truncate(
      totalNewRewards,
      exponential::exp((indexStaked as u128), (totalStaked as u128)),
    );
    prevIndex + (newIndexReward as u64)
  }
  
  /**
   * @notice Calculate the newly generated stake reward for a StakeCheck.
   * @param staked : Staked amount of the check
   * @param localIndex : index of the check
   * @param indexStaked : staked amount of the index
   * @param index : index of the pool
   * @returns : the newly accured reward for the check
   */
  public fun calc_stake_reward(
    staked: u64,
    localIndex: u64,
    indexStaked: u64,
    index: u64,
  ): u64 {
    /********
      stakeReward = (staked / indexStaked) * (poolIndex - index)
    ********/
    let stakeReward = exponential::mul_scalar_exp_truncate(
      ((index - localIndex) as u128),
      exponential::exp((staked as u128), (indexStaked as u128)),
    );
    (stakeReward as u64)
  }
}
