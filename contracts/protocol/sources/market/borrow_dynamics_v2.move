// This is used to calculate the debt interests
module protocol::borrow_dynamics_v2 {
  
  use std::type_name::{TypeName, get};
  use sui::table::{Self, Table};
  use decimal::decimal::{Self, Decimal};

  friend protocol::market;

  struct BorrowDynamicV2 has copy, store {
    interest_rate: Decimal,
    borrow_index: Decimal,
    last_updated: u64,
  }
  
  public fun interest_rate(dynamic: &BorrowDynamicV2): Decimal { dynamic.interest_rate }
  public fun borrow_index(dynamic: &BorrowDynamicV2): Decimal { dynamic.borrow_index }
  public fun last_updated(dynamic: &BorrowDynamicV2): u64 { dynamic.last_updated }

  public fun initial_borrow_index(): u64 {
    std::u64::pow(10, 9)
  }

  public(friend) fun new(
    self: &mut Table<TypeName, BorrowDynamicV2>,
    asset_type_name: TypeName,
    interest_rate: Decimal,
    borrow_index: Decimal,
    last_updated: u64,
  ) {
     let borrow_dynamic = BorrowDynamicV2 {
      interest_rate: interest_rate,
      borrow_index: borrow_index,
      last_updated: last_updated,
    };
    table::add(self, asset_type_name, borrow_dynamic);
  }

  public(friend) fun register_coin<T>(
    self: &mut Table<TypeName, BorrowDynamicV2>,
    base_interest_rate: Decimal,
    now: u64,
  ) {
    let borrow_dynamic = BorrowDynamicV2 {
      interest_rate: base_interest_rate,
      borrow_index: decimal::from(initial_borrow_index()),
      last_updated: now,
    };
    let type_name = get<T>();
    table::add(self, type_name, borrow_dynamic);
  }
  
  public fun borrow_index_by_type(
    self: &Table<TypeName, BorrowDynamicV2>,
    type_name: TypeName,
  ): Decimal {
    let debt_dynamic = table::borrow(self, type_name);
    debt_dynamic.borrow_index
  }

  public fun last_updated_by_type(
    self: &Table<TypeName, BorrowDynamicV2>,
    type_name: TypeName,
  ): u64 {
    let debt_dynamic = table::borrow(self, type_name);
    debt_dynamic.last_updated
  }

  public(friend) fun update_borrow_index(
    self: &mut Table<TypeName, BorrowDynamicV2>,
    type_name: TypeName,
    now: u64
  ) {
    let debt_dynamic = table::borrow_mut(self, type_name);

    // if the borrow index is already updated, return
    if (debt_dynamic.last_updated == now) {
      return
    };

    // new_borrow_index = old_borrow_index + (old_borrow_index * interest_rate * time_delta)
    let time_delta = decimal::from(now - debt_dynamic.last_updated);
    // let index_delta =
    //   fixed_point32::multiply_u64(debt_dynamic.borrow_index, fixed_point32_empower::mul(time_delta, debt_dynamic.interest_rate));
    let index_delta = decimal::mul(debt_dynamic.borrow_index, decimal::mul(time_delta, debt_dynamic.interest_rate));
    debt_dynamic.borrow_index = decimal::add(debt_dynamic.borrow_index, index_delta);
    debt_dynamic.last_updated = now;
  }
  
  public(friend) fun update_interest_rate(
    self: &mut Table<TypeName, BorrowDynamicV2>,
    type_name: TypeName,
    new_interest_rate: Decimal,
  ) {
    let debt_dynamic = table::borrow_mut(self, type_name);
    debt_dynamic.interest_rate = new_interest_rate;
  }
}
