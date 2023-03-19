// This is used to calculate the debt interests
module protocol::borrow_dynamics {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use sui::math;
  use x::wit_table::{Self, WitTable};
  use math::fixed_point32_empower;
  
  friend protocol::reserve;
  
  struct BorrowDynamics has drop {}
  
  struct BorrowDynamic has copy, store {
    interestRate: FixedPoint32,
    borrowIndex: u64,
    lastUpdated: u64,
  }
  
  public fun interest_rate(dynamic: &BorrowDynamic): FixedPoint32 { dynamic.interestRate }
  public fun borrow_index(dynamic: &BorrowDynamic): u64 { dynamic.borrowIndex }
  public fun last_updated(dynamic: &BorrowDynamic): u64 { dynamic.lastUpdated }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<BorrowDynamics, TypeName, BorrowDynamic> {
    wit_table::new<BorrowDynamics, TypeName, BorrowDynamic>(BorrowDynamics {}, true, ctx)
  }
  
  public(friend) fun register_coin<T>(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    baseInterestRate: FixedPoint32,
    now: u64,
  ) {
    let initialBorrowIndex = math::pow(10, 9);
    let borrowDynamic = BorrowDynamic {
      interestRate: baseInterestRate,
      borrowIndex: initialBorrowIndex,
      lastUpdated: now,
    };
    wit_table::add(BorrowDynamics{}, self, get<T>(), borrowDynamic)
  }
  
  public fun borrow_index_by_type(
    self: &WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
  ): u64 {
    let debtDynamic = wit_table::borrow(self, typeName);
    debtDynamic.borrowIndex
  }
  
  public(friend) fun update_borrow_index(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
    now: u64
  ) {
    let debtDynamic = wit_table::borrow_mut(BorrowDynamics {}, self, typeName);
    let timeDelta = fixed_point32_empower::from_u64(now - debtDynamic.lastUpdated);
    let indexDelta =
      fixed_point32::multiply_u64(debtDynamic.borrowIndex, fixed_point32_empower::mul(timeDelta, debtDynamic.interestRate));
    debtDynamic.borrowIndex = debtDynamic.borrowIndex + indexDelta;
    debtDynamic.lastUpdated = now;
  }
  
  public(friend) fun update_interest_rate(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
    newInterestRate: FixedPoint32,
  ) {
    let debtDynamic = wit_table::borrow_mut(BorrowDynamics {}, self, typeName);
    debtDynamic.interestRate = newInterestRate;
  }
}