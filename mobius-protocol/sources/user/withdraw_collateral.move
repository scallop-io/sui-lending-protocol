module mobius_protocol::withdraw_collateral {
  
  use std::type_name::TypeName;
  use sui::coin;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use time::timestamp::{Self ,TimeStamp};
  use x::ac_table::AcTable;
  use x::wit_table::WitTable;
  use mobius_protocol::position::{Self, Position};
  use mobius_protocol::interest_model::{InterestModels, InterestModel};
  use mobius_protocol::bank_state::{Self, BankStates, BankState};
  use mobius_protocol::evaluator;
  use mobius_protocol::collateral_config::{CollateralConfigs, CollateralConfig};
  
  public entry fun withdraw_collateral<T>(
    position: &mut Position,
    bankStates: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    collateralConfigs: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    timeOracle: &TimeStamp,
    withdrawAmount: u64,
    ctx: &mut TxContext,
  ) {
    // accrue interests for banks
    let now = timestamp::timestamp(timeOracle);
    // Always update bank state first
    // Because interest need to be accrued first before other operations
    bank_state::compound_interests(bankStates, interestModels, now);
  
    // accure interests for position
    position::accure_interests(position, bankStates);
    
    // calc the maximum withdraw amount
    // If withdraw too much, we only return rather than abort
    // So that we can still keep the interest compounding effect
    let maxWithdawAmount = evaluator::max_withdraw_amount<T>(position, collateralConfigs);
    if (withdrawAmount > maxWithdawAmount) { return };
    
    // withdraw collateral from position, send it to user
    let withdrawedBalance = position::withdraw_collateral<T>(position, withdrawAmount);
    transfer::transfer(
      coin::from_balance(withdrawedBalance, ctx),
      tx_context::sender(ctx)
    );
  }
}
