module mobius_core::user_operation {
  
  use mobius_core::position::{Self, Position};
  use sui::coin::{Self, Coin};
  use mobius_core::borrow_index::BorrowIndexTable;
  use mobius_core::bank_stats::BankStats;
  use time::timestamp::TimeStamp;
  use mobius_core::interest_model::InterestModelTable;
  use mobius_core::bank::Bank;
  use mobius_core::bank;
  
  public entry fun repay<T>(
    position: &mut Position,
    bank: &mut Bank<T>,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &mut BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    coin: Coin<T>,
  ) {
    position::remove_debt<T>(
      position,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
      coin::value(&coin)
    );
    bank::repay(
      bank,
      bankStats,
      borrowIndexTable,
      timeOracle,
      interestModelTable,
      coin::into_balance(coin)
    );
  }
}
