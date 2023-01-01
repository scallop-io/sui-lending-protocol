// This is used to calculate the debt interests
module protocol::borrow_dynamics {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use math::fr::{Self, Fr};
  use math::mix;
  
  struct BorrowDynamics has drop {}
  
  struct BorrowDynamic has store {
    interestRate: Fr,
    borrowIndex: Fr,
    lastUpdated: u64,
  }
  
  public fun new(ctx: &mut TxContext): WitTable<BorrowDynamics, TypeName, BorrowDynamic> {
    wit_table::new<BorrowDynamics, TypeName, BorrowDynamic>(BorrowDynamics {}, false, ctx)
  }
  
  public fun borrow_index(
    self: &WitTable<BorrowDynamics, TypeName, BorrowDynamic>,
    typeName: TypeName,
  ): Fr {
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
    debtDynamic.borrowIndex = fr::add(
      debtDynamic.borrowIndex,
      mix::mul_ifr(timeDelta, debtDynamic.interestRate)
    );
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
