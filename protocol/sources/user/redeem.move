module protocol::redeem {
  
  use std::type_name::TypeName;
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self ,TxContext};
  use sui::transfer;
  use time::timestamp::{Self ,TimeStamp};
  use x::ac_table::AcTable;
  use x::wit_table::WitTable;
  use protocol::bank::{Bank, BankCoin};
  use protocol::interest_model::{InterestModels, InterestModel};
  use protocol::bank_state::{Self, BankStates, BankState};
  
  public entry fun redeem<T>(
    bank: &mut Bank<T>,
    bankStates: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    timeOracle: &TimeStamp,
    coin: Coin<BankCoin<T>>,
    ctx: &mut TxContext,
  ) {
    let now = timestamp::timestamp(timeOracle);
    let redeemBalance = bank_state::handle_redeem(
      bankStates,
      bank,
      interestModels,
      coin::into_balance(coin),
      now
    );
    transfer::transfer(
      coin::from_balance(redeemBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
