// Borrow rate index
module mobius_core::borrow_index {
  
  use sui::object::UID;
  use sui::table::Table;
  use std::type_name::{TypeName, get};
  use math::exponential::Exp;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::object;
  use sui::table;
  use time::timestamp;
  use time::timestamp::TimeStamp;
  use mobius_core::interest_model::InterestModelTable;
  use mobius_core::interest_model;
  use mobius_core::bank::Bank;
  use mobius_core::bank;
  use math::exponential;
  use mobius_core::bank_stats::BankStats;
  use mobius_core::bank_stats;
  
  struct BorrowIndex has tore {
    lastUpdated: u64,
    index: Exp
  }
  
  struct BorrowIndexTable has key {
    id: UID,
    table: Table<TypeName, BorrowIndex>,
  }
  
  fun init(ctx: &mut TxContext) {
    transfer::share_object(
      BorrowIndexTable {
        id: object::new(ctx),
        table: table::new(ctx)
      }
    )
  }
  
  fun update(
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    typeName: TypeName,
  ) {
    // get the borrow index
    let borrowIndex = table::borrow_mut(&mut borrowIndexTable.table, typeName);
    // get the current timestamp
    let now = timestamp::timestamp(timeOracle);
    // get the bank balance sheet
    let ( totalLending,totalCash, _ ) = bank_stats::get(bankStats, typeName);
    
    // calc the ultilization rate of the borrowing asset
    let ultiRate = exponential::exp(
      (totalLending as u128),
      ((totalCash + totalLending) as u128),
    );
    // calc the borrow rate per second according to interest model and ultilization rate
    let borrowRate = interest_model::calc_interest_of_type(
      interestModelTable,
      typeName,
      ultiRate,
    );
    // the time passed
    let timeDelta = now - borrowIndex.lastUpdated;
    
    // update the borrow index
    let indexDelta = exponential::mul_exp(
      borrowIndex.index,
      exponential::mul_scalar_exp(borrowRate, (timeDelta as u128)),
    );
    borrowIndex.index = exponential::add_exp(
      borrowIndex.index,
      indexDelta
    );
    // update the lastUpdated for borrow index
    borrowIndex.lastUpdated = now;
  }
}
