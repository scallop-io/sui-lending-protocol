module bullshark_quest::suifren_lucky_draw {

  use sui::clock::{Self, Clock};
  use sui::dynamic_field;
  use sui::event::emit;
  use sui::object::{Self, ID, UID};
  use sui::tx_context::{Self, TxContext};

  use suifrens::suifrens::SuiFren;
  use suifrens::bullshark::Bullshark;
  use suifrens::capy::Capy;

  use bullshark_quest::quest_point_lottery;

  /// Each bullshark can only draw 1 ticket per epoch
  const BULLSHARK_TICKET_PER_EPOCH: u64 = 1;
  /// Each capy can draw 3 tickets per epoch
  const CAPY_TICKET_PER_EPOCH: u64 = 3;

  // ========== Error codes ============ //
  const TICKET_USED_UP: u64 = 0x2001;

  struct LuckyDrawCampaign has key {
    id: UID
  }

  struct LuckyDrawTicket has key {
    id: UID,
    drand_round: u64,
  }

  // ========== Record Keys ============ //
  struct BullsharkRecordKey has store, copy, drop {
    bullshark_id: ID,
    epoch: u64,
  }

  struct CapyRecordKey has store, copy, drop {
    capy_id: ID,
    epoch: u64,
  }

  // ========== Events ============ //
  struct BullsharkLuckyDrawEvent has copy, drop {
    bullshark_id: ID,
    ticket_id: ID,
    epoch: u64,
    timestamp: u64,
  }

  struct CapyLuckyDrawEvent has copy, drop {
    capy_id: ID,
    ticket_id: ID,
    epoch: u64,
    timestamp: u64,
  }

  /// Draw a ticket from the lottery to the Bullshark holder
  public fun bullshark_lucky_draw(
    bullshark: &mut SuiFren<Bullshark>,
    campaign: &mut LuckyDrawCampaign,
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    bullshark_join_campaign(bullshark, campaign, ctx);
    let ticket_id = quest_point_lottery::draw_ticket(drand_sig, drand_prev_sig, drand_round, clock, ctx);
    emit(
      BullsharkLuckyDrawEvent {
        bullshark_id: object::id(bullshark),
        ticket_id,
        epoch: tx_context::epoch(ctx),
        timestamp: clock::timestamp_ms(clock),
      }
    );
  }

  /// Draw a ticket from the lottery to the Capy holder
  public fun capy_lucky_draw(
    capy: &mut SuiFren<Capy>,
    campaign: &mut LuckyDrawCampaign,
    drand_sig: vector<u8>,
    drand_prev_sig: vector<u8>,
    drand_round: u64,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    capy_join_campaign(capy, campaign, ctx);
    let ticket_id = quest_point_lottery::draw_ticket(drand_sig, drand_prev_sig, drand_round, clock, ctx);
    emit(
      CapyLuckyDrawEvent {
        capy_id: object::id(capy),
        ticket_id,
        epoch: tx_context::epoch(ctx),
        timestamp: clock::timestamp_ms(clock),
      }
    );
  }

  /// Make sure each bullshark can only draw 1 ticket per epoch
  fun bullshark_join_campaign(
    bullshark: &mut SuiFren<Bullshark>,
    campaign: &mut LuckyDrawCampaign,
    ctx: &mut TxContext,
  ) {
    let bullshark_id = object::id(bullshark);
    let key = BullsharkRecordKey {
      bullshark_id,
      epoch: tx_context::epoch(ctx),
    };
    if (dynamic_field::exists_(&campaign.id, key)) {
      let drawed = dynamic_field::borrow_mut<BullsharkRecordKey, u64>(&mut campaign.id, key);
      assert!(*drawed < BULLSHARK_TICKET_PER_EPOCH, TICKET_USED_UP);
      *drawed = *drawed + 1;
    } else {
      dynamic_field::add(&mut campaign.id, key, 1);
    };
  }

  /// Make sure each capy can only draw 3 tickets per epoch
  fun capy_join_campaign(
    capy: &mut SuiFren<Capy>,
    campaign: &mut LuckyDrawCampaign,
    ctx: &mut TxContext,
  ) {
    let capy_id = object::id(capy);
    let key = CapyRecordKey {
      capy_id,
      epoch: tx_context::epoch(ctx),
    };
    if (dynamic_field::exists_(&campaign.id, key)) {
      let drawed = dynamic_field::borrow_mut<CapyRecordKey, u64>(&mut campaign.id, key);
      assert!(*drawed < CAPY_TICKET_PER_EPOCH, TICKET_USED_UP);
      *drawed = *drawed + 1;
    } else {
      dynamic_field::add(&mut campaign.id, key, 1);
    };
  }
}
