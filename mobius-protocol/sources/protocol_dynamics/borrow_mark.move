// Borrow marks from the time bank created
// This is the single source of truth for calculating interest for postion and bank
module mobius_protocol::borrow_mark {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use math::exponential::{Self, Exp};
  use x::wit_table::{Self, WitTable};
  
  struct BorrowMark has store {
    lastUpdated: u64,
    mark: Exp,
    interestRate: Exp,
  }
  
  struct BorrowMarks has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<BorrowMarks, TypeName, BorrowMark> {
    wit_table::new<BorrowMarks, TypeName, BorrowMark>(BorrowMarks{}, false, ctx)
  }
  
  public fun get_borrow_mark(
    borrowMarks: &WitTable<BorrowMarks, TypeName, BorrowMark>,
    typeName: TypeName,
  ): Exp {
    let mark = wit_table::borrow(borrowMarks, typeName);
    mark.mark
  }
  
  // return newly refreshed borrow mark
  public fun refresh_borrow_mark(
    borrowMarks: &mut WitTable<BorrowMarks, TypeName, BorrowMark>,
    typeName: TypeName,
    now: u64,
  ): Exp {
    let borrowMark = wit_table::borrow_mut(BorrowMarks{}, borrowMarks, typeName);
    accrue_borrow_mark(borrowMark, now)
  }
  
  public fun update_interest_rate(
    borrowMarks: &mut WitTable<BorrowMarks, TypeName, BorrowMark>,
    typeName: TypeName,
    interestRate: Exp
  ) {
    let borrowMark = wit_table::borrow_mut(BorrowMarks{}, borrowMarks, typeName);
    borrowMark.interestRate = interestRate
  }
  
  
  fun accrue_borrow_mark(borrowMark: &mut BorrowMark, now: u64): Exp {
    // the time passed
    let timeDelta = ((now - borrowMark.lastUpdated) as u128);
    // update the borrow mark
    let delta = exponential::mul_exp(
      borrowMark.mark,
      exponential::mul_scalar_exp(borrowMark.interestRate, timeDelta),
    );
    borrowMark.mark = exponential::add_exp(
      borrowMark.mark,
      delta
    );
    // update the lastUpdated for borrow index
    borrowMark.lastUpdated = now;
    borrowMark.mark
  }
}
