module stake::reward {
  use sui::object::{Self, UID};
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin};
  use sui::tx_context::TxContext;
  use stake::admin::StakeAdminCap;
  use stake::admin;
  
  friend stake::action;
  
  struct StakeRewardTreasury<phantom Wit, phantom RewardType> has key, store {
    id: UID,
    balance: Balance<RewardType>
  }
  
  const EAdminNotAllowedToTakeRewards: u64 = 0;
  
  public fun create_treasury<Wit, RewardType>(
    _: &StakeAdminCap<Wit>,
    coin: Coin<RewardType>,
    ctx: &mut TxContext
  ): StakeRewardTreasury<Wit, RewardType> {
    StakeRewardTreasury {
      id: object::new(ctx),
      balance: coin::into_balance(coin)
    }
  }
  
  public fun topup_rewards<Wit, RewardType>(
    rewardTreasury: &mut StakeRewardTreasury<Wit, RewardType>,
    coin: Coin<RewardType>,
  ) {
    balance::join(&mut rewardTreasury.balance, coin::into_balance(coin));
  }
  
  public fun take_rewards<Wit, RewardType>(
    adminCap: &StakeAdminCap<Wit>,
    rewardTreasury: &mut StakeRewardTreasury<Wit, RewardType>,
    coin: Coin<RewardType>,
  ) {
    assert!(admin::can_take_away_rewards(adminCap), EAdminNotAllowedToTakeRewards);
    balance::join(&mut rewardTreasury.balance, coin::into_balance(coin));
  }
  
  public(friend) fun mint<Wit, RewardType>(
    treasury: &mut StakeRewardTreasury<Wit, RewardType>,
    amount: u64
  ): Balance<RewardType> {
    balance::split(&mut treasury.balance, amount)
  }
}
