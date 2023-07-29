module bullshark_quest::borrow_quest {

  use sui::clock::{Self, Clock};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;

  use protocol::obligation::{Self, ObligationKey, Obligation};
  use protocol::obligation_access::ObligationAccessStore;

  use bullshark_quest::quest_point::{Self, QuestPointTreasury};
  use bullshark_quest::quest_controller::{Self, QuestController};

  const REDEEM_POINT_TOO_SMALL: u64 = 0x111;

  struct BORROW_QUEST_KEY has drop {}

  struct BrrowQuestPointRedeemed has copy, drop {
    address: address,
    borrow_point: u64,
    quest_point: u64,
    timestamp: u64,
  }

  public fun redeem_borrow_quest_point(
    obligation: &mut Obligation,
    obligation_key: &ObligationKey,
    obligation_access_store: &ObligationAccessStore,
    quest_point_treasury: &mut QuestPointTreasury,
    quest_controller: &QuestController,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let borrow_point = obligation::rewards_point(obligation);
    obligation::redeem_rewards_point(
      obligation,
      obligation_key,
      obligation_access_store,
      BORROW_QUEST_KEY {},
      borrow_point
    );
    let quest_point = quest_controller::borrow_point_to_quest_point(
      quest_controller,
      borrow_point,
    );
    assert!(quest_point > 0, REDEEM_POINT_TOO_SMALL);
    quest_point::mint_to_address(
      quest_point_treasury,
      quest_point,
      tx_context::sender(ctx),
      clock,
      ctx
    );
    emit(
      BrrowQuestPointRedeemed {
        address: tx_context::sender(ctx),
        quest_point,
        borrow_point,
        timestamp: clock::timestamp_ms(clock),
      }
    );
  }
}
