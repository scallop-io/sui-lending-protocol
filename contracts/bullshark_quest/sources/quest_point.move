module bullshark_quest::quest_point {

  use sui::balance::{Self, Balance, Supply};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use sui::event::emit;

  friend bullshark_quest::borrow_quest;
  friend bullshark_quest::suifren_lucky_draw;
  friend bullshark_quest::quest_point_lottery;

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

  // ================== Events ================== //
  struct QuestPointMinted has copy, drop {
    point: u64,
    address: address,
    timestamp: u64,
  }

  fun init(otw: QUEST_POINT, ctx: &mut TxContext) {
    let supply = balance::create_supply(otw);
    let treasury = QuestPointTreasury { id: object::new(ctx), supply };
    transfer::share_object(treasury);
  }

  /// We only allow mint to the sender, as the event need to enforce the point is not transferrable
  public(friend) fun mint_to_sender(
    quest_point_treasury: &mut QuestPointTreasury,
    amount: u64,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let balance = balance::increase_supply(
      &mut quest_point_treasury.supply,
      amount
    );
    let timestamp = clock::timestamp_ms(clock);
    let point = QuestPoint { id: object::new(ctx), balance, issue_timestamp: timestamp };
    let recipient = tx_context::sender(ctx);
    transfer::transfer(point, recipient);
    emit(QuestPointMinted { point: amount, address: recipient, timestamp });
  }
}
