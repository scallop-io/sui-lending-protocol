module bullshark_quest::paid_lucky_draw {

  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::object::ID;
  use sui::sui::SUI;
  use sui::event::emit;


  use bullshark_quest::quest_point_lottery;
  use bullshark_quest::quest_controller::{Self, QuestController};

  const NOT_ENOUGH_FEE: u64 = 0x4001;

  // ====================== Events ====================== //
  struct PaidLuckyDrawEvent has copy, drop {
    ticket_id: ID,
    paid_amount: u64,
    timestamp: u64,
    address: address,
  }

  /// Pay a fee to enter the lucky draw.
  /// User could buy any number of tickets
  public fun paid_lucky_draw(
    fee: Coin<SUI>,
    controller: &mut QuestController,
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let ticket_price = quest_controller::ticket_price(controller);
    let fee_amount = coin::value(&fee);
    assert!(fee_amount >= ticket_price, NOT_ENOUGH_FEE);
    quest_controller::collect_fees(controller, coin::into_balance(fee));
    let ticket_id = quest_point_lottery::draw_ticket(
      drand_sig,
      drand_prev_sig,
      drand_round,
      clock,
      ctx,
    );
    emit(
      PaidLuckyDrawEvent {
        ticket_id,
        paid_amount: fee_amount,
        timestamp: clock::timestamp_ms(clock),
        address: tx_context::sender(ctx),
      }
    );
  }
}
