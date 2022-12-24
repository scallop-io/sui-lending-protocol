module mobius_protocol::mint {
  use std::type_name::TypeName;
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::transfer;
  use time::timestamp::{Self ,TimeStamp};
  use x::ac_table::AcTable;
  use x::wit_table::WitTable;
  use mobius_protocol::bank::Bank;
  use mobius_protocol::interest_model::{InterestModels, InterestModel};
  use mobius_protocol::bank_state::{Self, BankStates, BankState};
  
  public entry fun mint<T>(
    bank: &mut Bank<T>,
    bankStates: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    timeOracle: &TimeStamp,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let now = timestamp::timestamp(timeOracle);
    let mintBalance = bank_state::handle_mint(
      bankStates,
      bank,
      interestModels,
      coin::into_balance(coin),
      now
    );
    transfer::transfer(
      coin::from_balance(mintBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
