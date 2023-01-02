module protocol::reward_model {
  
  struct RewardModels has drop {}
  
  struct RewardModel has store {
    indexStaked: u64,
    rewardsPerSec: u64
  }
  
  
}
