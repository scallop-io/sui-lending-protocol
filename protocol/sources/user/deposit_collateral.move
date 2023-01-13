module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName, get};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::position::{Self, Position};
  use protocol::bank::{Self, Bank};
  
  const EIllegalCollateralType: u64 = 0;
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    position: ID,
    depositAsset: TypeName,
    depositAmount: u64,
  }
  
  public entry fun deposit_collateral<T>(
    position: &mut Position,
    bank: &Bank,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let hasRiskModel = bank::has_risk_model(bank, get<T>());
    assert!(hasRiskModel == true, EIllegalCollateralType);
    
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      position: object::id(position),
      depositAsset: type_name::get<T>(),
      depositAmount: coin::value(&coin),
    });
  
    position::deposit_collateral(position, coin::into_balance(coin))
  }
}
