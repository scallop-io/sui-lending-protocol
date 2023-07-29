module bullshark_quest::quest_controller {

  use std::fixed_point32::{Self, FixedPoint32};
  use sui::math;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer;

  struct QuestController has key {
    id: UID,
    borrow_point_rate: FixedPoint32, // the rate of borrow point to quest point
    first_place_point: u64,
    second_place_point: u64,
    third_place_point: u64,
    fourth_place_point: u64,
    no_luck_point: u64,
  }

  fun init(ctx: &mut TxContext) {
    let initial_borrow_point_rate = fixed_point32::create_from_rational(
      1,
      math::pow(10, 7)
    );
    let controller = QuestController {
      id: object::new(ctx),
      borrow_point_rate: initial_borrow_point_rate,
      first_place_point: 100000,
      second_place_point: 10000,
      third_place_point: 1000,
      fourth_place_point: 100,
      no_luck_point: 10,
    };
    transfer::share_object(controller);
  }

  public fun first_place_point(controller: &QuestController): u64 { controller.first_place_point }
  public fun second_place_point(controller: &QuestController): u64 { controller.second_place_point }
  public fun third_place_point(controller: &QuestController): u64 { controller.third_place_point }
  public fun fourth_place_point(controller: &QuestController): u64 { controller.fourth_place_point }
  public fun no_luck_point(controller: &QuestController): u64 { controller.no_luck_point }


  /// Convert the borrow point to bullshark quest point.
  public fun borrow_point_to_quest_point(
    controller: &QuestController,
    borrow_point: u64,
  ): u64 {
    fixed_point32::multiply_u64(borrow_point, controller.borrow_point_rate)
  }
}
