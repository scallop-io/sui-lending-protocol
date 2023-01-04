// This is used to calculate the debt interests
module protocol::borrow_dynamics {
  
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use math::fr::Fr;
  use sui::math;
  use math::fr;
  
  struct BorrowDynamics has drop {}
  
  struct BorrowDynamic has store {
    interestRate: Fr,
    borrowIndex: u64,
    lastUpdated: u64,
  }
  
  public fun interest_rate(dynamic: &BorrowDynamic): Fr { dynamic.interestRate }
  public fun borrow_index(dynamic: &BorrowDynamic): u64 { dynamic.borrowIndex }
  public fun last_updated(dynamic: &BorrowDynamic): u64 { dynamic.lastUpdated }
  
  public fun new(ctx: &mut TxContext): WitTable<BorrowDynamics, TypeName, BorrowDynamic> {
    wit_table::new<BorrowDynamics, TypeName, BorrowDynamic>(BorrowDynamics {}, false, ctx)
  }
  
  public fun register_coin<T>(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    baseInterestRate: Fr,
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
  
  public fun update_borrow_index(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
    now: u64
  ) {
    let debtDynamic = wit_table::borrow_mut(BorrowDynamics {}, self, typeName);
    let timeDelta = now - debtDynamic.lastUpdated;
    debtDynamic.borrowIndex =
      debtDynamic.borrowIndex + fr::mul_iT(fr::mul_i(debtDynamic.interestRate, timeDelta), debtDynamic.borrowIndex);
    debtDynamic.lastUpdated = now;
  }
  
  public fun update_interest_rate(
    self: &mut WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
    newInterestRate: Fr,
  ) {
    let debtDynamic = wit_table::borrow_mut(BorrowDynamics {}, self, typeName);
    debtDynamic.interestRate = newInterestRate;
  }
}
