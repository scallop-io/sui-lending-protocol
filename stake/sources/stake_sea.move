// Sea for all the stake pools and the stake reward
module stake::stake_sea {
  
  use std::type_name::{Self, TypeName};
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::balance::Balance;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, UID};
  use sui::object_bag::{Self, ObjectBag};
  use stake::pool::{Self, StakePool};
  use stake::admin::{Self, StakeAdminCap};
  use stake::reward::{Self, StakeRewardTreasury};
  use stake::action;
  use stake::check::StakeCheck;
  
  const IndexStaked: u64 = 1000000000;
  
  struct StakeSea<phantom Wit, phantom Reward> has key, store {
    id: UID,
    pools: ObjectBag,
    rewardTreasury: StakeRewardTreasury<Wit, Reward>,
  }
  
  public fun new<Wit: drop, Reward>(
    witness: Wit,
    ctx: &mut TxContext,
  ): (StakeSea<Wit, Reward>, StakeAdminCap<Wit>) {
    let stakeAdmin = admin::issue_admin_cap<Wit>(witness, false, ctx);
    let stakeSea = StakeSea {
      id: object::new(ctx),
      pools: object_bag::new(ctx),
      rewardTreasury: reward::create_treasury(ctx),
    };
    (stakeSea, stakeAdmin)
  }
  
  public entry fun take_rewards<Wit, Reward>(
    adminCap: &StakeAdminCap<Wit>,
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<Reward>
  ) {
    reward::take_rewards(adminCap, &mut self.rewardTreasury, coin)
  }
  
  public entry fun topup_rewards<Wit, Reward>(
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<Reward>
  ) {
    reward::topup_rewards(&mut self.rewardTreasury, coin)
  }
  
  public entry fun create_pool<Wit, Reward, StakeCoin>(
    _: &StakeAdminCap<Wit>,
    self: &mut StakeSea<Wit, Reward>,
    rewardPerSec: u64,
    now: u64,
    ctx: &mut TxContext,
  ) {
    let pool = pool::create_pool<Wit, Reward, StakeCoin>(rewardPerSec, IndexStaked, now, ctx);
    let poolName = type_name::get<StakeCoin>();
    object_bag::add(&mut self.pools, poolName, pool);
  }
  
  public fun stake<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<StakeCoin>,
    now: u64,
    ctx: &mut TxContext
  ): StakeCheck<Wit, Reward, StakeCoin> {
    let pool = borrow_pool_mut(self);
    action::stake(coin, pool, now, ctx)
  }
  
  public entry fun stake_<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<StakeCoin>,
    now: u64,
    ctx: &mut TxContext
  ) {
    let stakeCheck = stake(self, coin, now, ctx);
    transfer::transfer(stakeCheck, tx_context::sender(ctx));
  }
  
  public entry fun stake_more<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<StakeCoin>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    now: u64,
  ) {
    let pool = borrow_pool_mut(self);
    action::stake_more(coin, stakeCheck, pool, now)
  }
  
  public fun unstake<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    unstakeAmount: u64,
    now: u64,
  ): (Balance<StakeCoin>, Balance<Reward>) {
    let poolType = type_name::get<StakeCoin>();
    let pool = object_bag::borrow_mut<TypeName, StakePool<Wit, Reward, StakeCoin>>(&mut self.pools, poolType);
    let rewardTreasury = &mut self.rewardTreasury;
    action::unstake(stakeCheck, pool, rewardTreasury, unstakeAmount, now)
  }
  
  public entry fun unstake_<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    unstakeAmount: u64,
    now: u64,
    ctx: &mut TxContext,
  ) {
    let (stakeCoinBanlance, rewardBalance) = unstake(self, stakeCheck, unstakeAmount, now);
    let sender = tx_context::sender(ctx);
    transfer::transfer(coin::from_balance(stakeCoinBanlance, ctx), sender);
    transfer::transfer(coin::from_balance(rewardBalance, ctx), sender);
  }
  
  fun borrow_pool_mut<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
  ): &mut StakePool<Wit, Reward, StakeCoin> {
    let poolType = type_name::get<StakeCoin>();
    object_bag::borrow_mut<TypeName, StakePool<Wit, Reward, StakeCoin>>(&mut self.pools, poolType)
  }
}
