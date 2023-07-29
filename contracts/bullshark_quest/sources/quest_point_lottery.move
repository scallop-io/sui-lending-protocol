module bullshark_quest::quest_point_lottery {

  use std::vector;

  use sui::object::{Self, UID, ID};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::hash::blake2b256;
  use sui::transfer;
  use sui::event::emit;

  use bullshark_quest::drand_lib;
  use bullshark_quest::quest_point::{Self, QuestPointTreasury};
  use bullshark_quest::quest_controller::{Self, QuestController};

  friend bullshark_quest::quest_point_lottery_suifren;
  friend bullshark_quest::quest_point_lottery_paid;

  const PLACE_BASE: u64 = 10000;
  const FIRST_PLACE_THRESHOLD: u64 = 1; // 0.01% to win the first place.
  const SECOND_PLACE_THRESHOLD: u64 = 10; // 0.1% to win the second place.
  const THIRD_PLACE_THRESHOLD: u64 = 100; // 1% to win the third place.
  const FOURTH_PLACE_THRESHOLD: u64 = 1000; // 10% to win the fourth place.

  const FIRST_PLACE: u64 = 1;
  const SECOND_PLACE: u64 = 2;
  const THIRD_PLACE: u64 = 3;
  const FOURTH_PLACE: u64 = 4;
  const NO_LUCK: u64 = 5;

  const INVALID_REDEEM_ROUND: u64 = 0x5001;

  /// Ticket is not transferable.
  struct LuckyDrawTicket has key {
    id: UID,
    drand_round: u64,
  }

  // =========== Events =========== //
  struct QuestPointTicketDrawnEvent has copy, drop {
    ticket_id: ID,
    drand_round: u64,
    address: address,
    timestamp: u64,
  }

  struct QuestPointTicketRedeemedEvent has copy, drop {
    ticket_id: ID,
    prize_level: u64,
    prize_point: u64,
    address: address,
    timestamp: u64,
  }

  /// Draw a ticket based on the current drand round.
  public(friend) fun draw_ticket(
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): ID {
    drand_lib::is_current_round(drand_sig, drand_prev_sig, drand_round, clock);
    let ticket = LuckyDrawTicket { id: object::new(ctx), drand_round };
    let recipient = tx_context::sender(ctx);
    let ticket_id = object::id(&ticket);
    emit(
      QuestPointTicketDrawnEvent {
        ticket_id,
        drand_round,
        address: tx_context::sender(ctx),
        timestamp: clock::timestamp_ms(clock),
      },
    );
    transfer::transfer(ticket, recipient);
    ticket_id
  }

  /// Redeem the ticket based on the ticket id and the drand signature.
  public fun redeem_ticket(
    ticket: LuckyDrawTicket,
    quest_point_treasury: &mut QuestPointTreasury,
    quest_controller: &QuestController,
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ): u64 {
    let prize_level = calc_ticket_prize_level(&ticket, drand_sig, drand_prev_sig, drand_round);
    let prize_point = get_point_by_prize_level(quest_controller, prize_level);
    quest_point::mint_to_sender(quest_point_treasury, prize_point, clock, ctx);
    emit(
      QuestPointTicketRedeemedEvent {
        ticket_id: object::id(&ticket),
        prize_level,
        prize_point,
        address: tx_context::sender(ctx),
        timestamp: clock::timestamp_ms(clock),
      },
    );
    let LuckyDrawTicket { id, drand_round: _ } = ticket;
    object::delete(id);
    prize_point
  }

  /// Calculate the prize level based on the ticket id and the drand signature.
  fun calc_ticket_prize_level(
    ticket: &LuckyDrawTicket,
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
  ): u64 {
    // Make sure the ticket is redeemed with the correct round.
    assert!(ticket.drand_round + 2 == drand_round, INVALID_REDEEM_ROUND);
    // Make sure the round is legit.
    drand_lib::verify_drand_signature(drand_sig, drand_prev_sig, drand_round);

    // Generate random bytes from the drand signature and the ticket id.
    let random_bytes = drand_sig;
    let uid_bytes = object::uid_to_bytes(&ticket.id);
    vector::append(&mut random_bytes, uid_bytes);

    // Hash the random bytes to get the random hash.
    let random_hash = blake2b256(&random_bytes);

    // Calculate the prize level based on the random hash.
    let random_number = drand_lib::safe_selection(PLACE_BASE, &random_hash);
    if (random_number <= FIRST_PLACE_THRESHOLD) {
      FIRST_PLACE
    } else if (random_number <= SECOND_PLACE_THRESHOLD) {
      SECOND_PLACE
    } else if (random_number <= THIRD_PLACE_THRESHOLD) {
      THIRD_PLACE
    } else if (random_number <= FOURTH_PLACE_THRESHOLD) {
      FOURTH_PLACE
    } else {
      NO_LUCK
    }
  }

  /// Get the point based on the prize level.
  fun get_point_by_prize_level(quest_controller: &QuestController, prize_level: u64): u64 {
    if (prize_level == FIRST_PLACE) {
      quest_controller::first_place_point(quest_controller)
    } else if (prize_level == SECOND_PLACE) {
      quest_controller::second_place_point(quest_controller)
    } else if (prize_level == THIRD_PLACE) {
      quest_controller::third_place_point(quest_controller)
    } else if (prize_level == FOURTH_PLACE) {
      quest_controller::fourth_place_point(quest_controller)
    } else {
      quest_controller::no_luck_point(quest_controller)
    }
  }
}
