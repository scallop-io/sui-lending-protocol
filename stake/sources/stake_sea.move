// Sea for all the stake pools and the stake reward
module stake::stake_sea {
  
  use std::type_name::TypeName;
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::balance::Balance;
  use sui::tx_context::{Self ,TxContext};
  use sui::object::{Self, UID};
  use x::wit_table::WitTable;
  use x::balance_bag::{Self, BalanceBag};
  use stake::pool::{Self, StakePool, StakePools};
  use stake::admin::{Self, StakeAdminCap};
  use stake::reward::{Self, StakeRewardTreasury};
  use stake::action;
  use stake::check::StakeCheck;
  
  const IndexStaked: u64 = 1000000000;
  
  struct StakeSea<phantom Wit, phantom Reward> has key, store {
    id: UID,
    pools: WitTable<StakePools, TypeName, StakePool>,
    stakeBalances: BalanceBag,
    rewardTreasury: StakeRewardTreasury<Wit, Reward>,
  }
  
  public fun pools<Wit, Reward>(self: &StakeSea<Wit, Reward>): &WitTable<StakePools, TypeName, StakePool> {
    &self.pools
  }
  public fun reward_treasury<Wit, Reward>(self: &StakeSea<Wit, Reward>): &StakeRewardTreasury<Wit, Reward> {
    &self.rewardTreasury
  }
  public fun stake_balances<Wit, Reward>(self: &StakeSea<Wit, Reward>): &BalanceBag {
    &self.stakeBalances
  }
  
  public fun new<Wit: drop, Reward>(
    witness: Wit,
    ctx: &mut TxContext,
  ): (StakeSea<Wit, Reward>, StakeAdminCap<Wit>) {
    let stakeAdmin = admin::issue_admin_cap<Wit>(witness, false, ctx);
    let stakeSea = StakeSea {
      id: object::new(ctx),
      pools: pool::new(ctx),
      stakeBalances: balance_bag::new(ctx),
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
  ) {
    pool::create_pool<StakeCoin>(&mut self.pools, rewardPerSec, IndexStaked, now);
  }
  
  public fun stake<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    coin: Coin<StakeCoin>,
    now: u64,
    ctx: &mut TxContext
  ): StakeCheck<Wit, Reward, StakeCoin> {
    action::stake(coin, &mut self.pools, &mut self.stakeBalances, now, ctx)
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
    action::stake_more(coin, stakeCheck, &mut self.pools, &mut self.stakeBalances, now);
  }
  
  public fun unstake<Wit, Reward, StakeCoin>(
    self: &mut StakeSea<Wit, Reward>,
    stakeCheck: &mut StakeCheck<Wit, Reward, StakeCoin>,
    unstakeAmount: u64,
    now: u64,
  ): (Balance<StakeCoin>, Balance<Reward>) {
    let rewardTreasury = &mut self.rewardTreasury;
    action::unstake(stakeCheck, &mut self.pools, &mut self.stakeBalances, rewardTreasury, unstakeAmount, now)
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
}
