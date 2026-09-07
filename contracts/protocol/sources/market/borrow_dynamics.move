// This is used to calculate the debt interests
module protocol::borrow_dynamics {
  
  use std::type_name::{Self, TypeName};
  use std::uq32_32::{Self, UQ32_32};
  use sui::tx_context::TxContext;
  use sui::math;
  use x::wit_table::{Self, WitTable};
  use math::UQ32_32_empower;

  friend protocol::market;
  
  struct BorrowDynamics has drop {}
  
  struct BorrowDynamic has copy, store {
    interest_rate: UQ32_32,
    interest_rate_scale: u64,
    borrow_index: u64,
    last_updated: u64,
  }
  
  public fun interest_rate(dynamic: &BorrowDynamic): UQ32_32 { dynamic.interest_rate }
  public fun interest_rate_scale(dynamic: &BorrowDynamic): u64 { dynamic.interest_rate_scale }
  public fun borrow_index(dynamic: &BorrowDynamic): u64 { dynamic.borrow_index }
  public fun last_updated(dynamic: &BorrowDynamic): u64 { dynamic.last_updated }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<BorrowDynamics, TypeName, BorrowDynamic> {
    wit_table::new<BorrowDynamics, TypeName, BorrowDynamic>(BorrowDynamics {}, true, ctx)
  }

  // when adding base asset, it should be called
  #[allow(unused_type_parameter)]
  public(friend) fun register_coin<T>(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    base_interest_rate: UQ32_32,
    interest_rate_scale: u64,
    now: u64,
  ) {
    let initial_borrow_index = std::u64::pow(10, 9);
    let borrow_dynamic = BorrowDynamic {
      interest_rate: base_interest_rate,
      interest_rate_scale,
      borrow_index: initial_borrow_index,
      last_updated: now,
    };
    wit_table::add(BorrowDynamics{}, self,  type_name::with_defining_ids<T>(), borrow_dynamic)
  }
  
  public fun borrow_index_by_type(
    self: &WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    type_name: TypeName,
  ): u64 {
    let debt_dynamic = wit_table::borrow(self, type_name);
    debt_dynamic.borrow_index
  }

  public fun last_updated_by_type(
    self: &WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    type_name: TypeName,
  ): u64 {
    let debt_dynamic = wit_table::borrow(self, type_name);
    debt_dynamic.last_updated
  }

  public(friend) fun update_borrow_index(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    type_name: TypeName,
    now: u64
  ) {
    let debt_dynamic = wit_table::borrow_mut(BorrowDynamics {}, self, type_name);

    // if the borrow index is already updated, return
    if (debt_dynamic.last_updated == now) {
      return
    };

    // new_borrow_index = old_borrow_index + (old_borrow_index * interest_rate * time_delta)
    let time_delta = UQ32_32_empower::from_u64(now - debt_dynamic.last_updated);
    let index_delta =
      uq32_32::int_mul(debt_dynamic.borrow_index, UQ32_32_empower::mul(time_delta, debt_dynamic.interest_rate));
    let index_delta = index_delta / debt_dynamic.interest_rate_scale;
    debt_dynamic.borrow_index = debt_dynamic.borrow_index + index_delta;
    debt_dynamic.last_updated = now;
  }
  
  public(friend) fun update_interest_rate(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    type_name: TypeName,
    new_interest_rate: UQ32_32,
    interest_rate_scale: u64,
  ) {
    let debt_dynamic = wit_table::borrow_mut(BorrowDynamics {}, self, type_name);
    debt_dynamic.interest_rate = new_interest_rate;
    debt_dynamic.interest_rate_scale = interest_rate_scale;
  }
}
