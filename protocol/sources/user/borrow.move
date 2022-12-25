module protocol::borrow {
  
  use std::type_name::{Self, TypeName};
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self ,TxContext};
  use time::timestamp::{Self ,TimeStamp};
  use x::ac_table::AcTable;
  use x::wit_table::WitTable;
  use protocol::position::{Self, Position};
  use protocol::bank::Bank;
  use protocol::interest_model::{InterestModels, InterestModel};
  use protocol::bank_state::{Self, BankStates, BankState};
  use protocol::evaluator;
  use protocol::collateral_config::{CollateralConfigs, CollateralConfig};
  
  public entry fun borrow<T>(
    position: &mut Position,
    bank: &mut Bank<T>,
    bankStates: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    timeOracle: &TimeStamp,
    borrowAmount: u64,
    ctx: &mut TxContext,
  ) {
    // accrue interests for banks
    let now = timestamp::timestamp(timeOracle);
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    let borrowedBalance = bank_state::handle_borrow<T>(
      bankStates,
      bank,
      interestModels,
      now,
      borrowAmount
    );
    
    // accure interests for position
    position::accure_interests(position, bankStates);
  
    // calc the maximum borrow amount
    // If borrow too much, abort
    let maxBorrowAmount = evaluator::max_borrow_amount<T>(position, collateralConfigs);
    assert!(borrowAmount > maxBorrowAmount, 0);
    
    // increase the debt for position
    let coinType = type_name::get<T>();
    position::increase_debt(position, coinType, borrowAmount);
    
    // lend the coin to user from bank
    transfer::transfer(
      coin::from_balance(borrowedBalance, ctx),
      tx_context::sender(ctx),
    );
  }
}
