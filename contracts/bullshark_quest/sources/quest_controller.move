module bullshark_quest::quest_controller {

  use std::fixed_point32::{Self, FixedPoint32};
  use sui::math;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::transfer;

  struct QuestController has key {
    id: UID,
    borrow_point_rate: FixedPoint32,
  }

  fun init(ctx: &mut TxContext) {
    let initial_borrow_point_rate = fixed_point32::create_from_rational(
      1,
      math::pow(10, 7)
    );
    let controller = QuestController {
      id: object::new(ctx),
      borrow_point_rate: initial_borrow_point_rate,
    };
    transfer::share_object(controller);
  }


  /// Convert the borrow point to bullshark quest point.
  public fun borrow_point_to_quest_point(
    controller: &QuestController,
    borrow_point: u64,
  ): u64 {
    fixed_point32::multiply_u64(borrow_point, controller.borrow_point_rate)
  }
}
