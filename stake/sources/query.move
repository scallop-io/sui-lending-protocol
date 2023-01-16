module stake::query {
  
  use std::vector;
  use std::type_name::{TypeName, get};
  use x::wit_table;
  use stake::stake_sea::{Self, StakeSea};
  use stake::pool::StakePool;
  use stake::reward;
  
  struct StakeData has copy {
    pools: vector<StakePool>,
    rewardAmount: u64,
    rewardType: TypeName,
  }
  
  public fun stake_data<Wit, RewardType>(stakeSea: &StakeSea<Wit, RewardType>): StakeData {
    let pools = stake_sea::pools(stakeSea);
    let types = wit_table::keys(pools);
    let (i, n) = (0, vector::length(&types));
    let poolsData = vector::empty<StakePool>();
    while(i < n) {
      let type = *vector::borrow(&types, i);
      let pool = *wit_table::borrow(pools, type);
      vector::push_back(&mut poolsData, pool);
      i = i + 1;
    };
    let rewardTreasury = stake_sea::reward_treasury(stakeSea);
    let rewardAmount = reward::reward_amount(rewardTreasury);
    StakeData { pools: poolsData, rewardAmount, rewardType: get<RewardType>() }
  }
}
