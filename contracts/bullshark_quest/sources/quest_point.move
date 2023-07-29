module bullshark_quest::quest_point {

  use sui::balance::{Self, Balance, Supply};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::TxContext;
  use sui::transfer;

  friend bullshark_quest::borrow_quest;

  struct QUEST_POINT has drop {}

  /// No store cap here, so can not be freely transfered
  struct QuestPoint has key {
    id: UID,
    balance: Balance<QUEST_POINT>,
    issue_timestamp: u64,
  }

  struct QuestPointTreasury has key {
    id: UID,
    supply: Supply<QUEST_POINT>
  }

  fun init(otw: QUEST_POINT, ctx: &mut TxContext) {
    let supply = balance::create_supply(otw);
    let treasury = QuestPointTreasury { id: object::new(ctx), supply };
    transfer::share_object(treasury);
  }

  public(friend) fun mint_to_address(
    quest_point_treasury: &mut QuestPointTreasury,
    amount: u64,
    recipient: address,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let balance = balance::increase_supply(
      &mut quest_point_treasury.supply,
      amount
    );
    let timestamp = clock::timestamp_ms(clock);
    let point = QuestPoint { id: object::new(ctx), balance, issue_timestamp: timestamp };
    transfer::transfer(point, recipient);
  }
}
