module stake::admin {
  
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  
  struct StakeAdminCap<phantom Wit> has key, store {
    id: UID,
    canTakeAwayRewards: bool
  }
  
  public fun issue_admin_cap<Wit: drop>(
    _: Wit,
    canTakeAwayRewards: bool,
    ctx: &mut TxContext
  ): StakeAdminCap<Wit> {
    StakeAdminCap { id: object::new(ctx), canTakeAwayRewards }
  }
  
  public fun can_take_away_rewards<Wit>(
    adminCap: &StakeAdminCap<Wit>
  ): bool {
    adminCap.canTakeAwayRewards
  }
}
