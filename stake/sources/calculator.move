// Put all reward calculating logic here
module stake::calculator {
  use math::u64;
  
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
    // When nothing is staked, just return 0
    if (totalStaked == 0) return 0;
    /********
      totalNewRewards = rewardRatePerSec * timeDelta
      newIndexReward = indexStaked * totalNewRewards / totalStaked;
      newIndex = prevIndex + newIndexReward
    *********/
    let totalNewRewards = rewardRatePerSec * timeDelta;
    let newIndexReward = u64::mul_div(indexStaked, totalNewRewards, totalStaked);
    prevIndex + newIndexReward
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
      stakeReward = (index - localIndex) * staked / indexStaked;
    ********/
    u64::mul_div(index - localIndex, staked, indexStaked)
  }
}
