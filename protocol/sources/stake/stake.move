module protocol::stake {
  
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use stake::admin::{Self, StakeAdminCap};
  use stake::pool::{Self, StakePool};
  use stake::reward::{Self, StakeRewardTreasury};
  
  use protocol::stake_reward::STAKE_REWARD;
  use sui::coin::Coin;
  use stake::action;
  use stake::check::StakeCheck;
  use sui::coin;
  
  struct Stake has drop {}
  
  struct XStakeAdminCap has key, store {
    id: UID,
    cap: StakeAdminCap<Stake>,
  }
  
  struct XStakeRewardTreasury has key {
    id: UID,
    treasury: StakeRewardTreasury<Stake, STAKE_REWARD>,
  }
  
  struct XStakePool<phantom StakeCoin> has key {
    id: UID,
    pool: StakePool<Stake, StakeCoin, STAKE_REWARD>
  }
  
  struct XStakeCheck<phantom StakeCoin> has key, store {
    id: UID,
    check: StakeCheck<Stake, StakeCoin, STAKE_REWARD>
  }
  
  fun init(ctx: &mut TxContext) {
    let stakeAdminCap = admin::issue_admin_cap(Stake {}, false, ctx);
    transfer::transfer(
      XStakeAdminCap {
        id: object::new(ctx),
        cap: stakeAdminCap
      },
      tx_context::sender(ctx)
    );
  }
  
  public entry fun create_stake_pool<StakeCoin>(
    cap: &XStakeAdminCap,
    rewardsPerSec: u64,
    indexStaked: u64,
    now: u64,
    ctx: &mut TxContext
  ) {
    let pool = pool::create_pool<Stake, StakeCoin, STAKE_REWARD>(
      &cap.cap, rewardsPerSec, indexStaked, now, ctx
    );
    transfer::share_object(
      XStakePool {
        id: object::new(ctx),
        pool
      }
    )
  }
  
  public entry fun create_reward_treasury(
    cap: &XStakeAdminCap,
    coin: Coin<STAKE_REWARD>,
    ctx: &mut TxContext
  ) {
    let rewardTreasury = reward::create_treasury<Stake, STAKE_REWARD>(&cap.cap, coin, ctx);
    transfer::share_object(
      XStakeRewardTreasury {
        id: object::new(ctx),
        treasury: rewardTreasury
      }
    )
  }
  
  public entry fun stake<StakeCoinType>(
    coin: Coin<StakeCoinType>,
    pool: &mut XStakePool<StakeCoinType>,
    now: u64,
    ctx: &mut TxContext
  ) {
    let check = action::stake(coin, &mut pool.pool, now, ctx);
    transfer::transfer(
      XStakeCheck {
        id: object::new(ctx),
        check,
      },
      tx_context::sender(ctx)
    );
  }
  
  public entry fun stake_more<StakeCoinType>(
    coin: Coin<StakeCoinType>,
    pool: &mut XStakePool<StakeCoinType>,
    check: &mut XStakeCheck<StakeCoinType>,
    now: u64,
  ) {
    action::stake_more(coin, &mut check.check, &mut pool.pool, now);
  }
  
  public entry fun unstake<StakeCoinType>(
    stakeCheck: &mut XStakeCheck<StakeCoinType>,
    pool: &mut XStakePool<StakeCoinType>,
    rewardTreasury: &mut XStakeRewardTreasury,
    unstakeAmount: u64,
    now: u64,
    ctx: &mut TxContext,
  ) {
    let (coinBalance, rewardBalance) = action::unstake(
      &mut stakeCheck.check,
      &mut pool.pool,
      &mut rewardTreasury.treasury,
      unstakeAmount,
      now,
    );
    let sender =tx_context::sender(ctx);
    transfer::transfer(
      coin::from_balance(coinBalance, ctx),
      sender
    );
    transfer::transfer(
      coin::from_balance(rewardBalance, ctx),
      sender
    );
  }
}
