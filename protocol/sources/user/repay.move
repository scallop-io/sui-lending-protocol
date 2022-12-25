module protocol::repay {

  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use time::timestamp::{Self ,TimeStamp};
  use x::ac_table::AcTable;
  use x::wit_table::WitTable;
  use protocol::position::{Self, Position};
  use protocol::bank::Bank;
  use protocol::interest_model::{InterestModels, InterestModel};
  use protocol::bank_state::{Self, BankStates, BankState};
  
  public entry fun repay<T>(
    position: &mut Position,
    bank: &mut Bank<T>,
    bankStates: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    timeOracle: &TimeStamp,
    coin: Coin<T>,
  ) {
    let now = timestamp::timestamp(timeOracle);
    let coinType = type_name::get<T>();
    let repayAmount = coin::value(&coin);
    
    // update bank balance sheet after repay
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    bank_state::handle_repay<T>(
      bankStates,
      bank,
      interestModels,
      coin::into_balance(coin),
      now
    );
  
    // accure interests for position
    position::accure_interests(position, bankStates);
    // remove debt according to repay amount
    position::decrease_debt(position, coinType, repayAmount);
  }
}
