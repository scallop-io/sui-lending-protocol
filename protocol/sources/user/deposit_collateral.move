module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName, get};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::obligation::{Self, Obligation};
  use protocol::reserve::{Self, Reserve};
  
  const EIllegalCollateralType: u64 = 0;
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    obligation: ID,
    depositAsset: TypeName,
    depositAmount: u64,
  }
  
  public entry fun deposit_collateral<T>(
    obligation: &mut Obligation,
    reserve: &mut Reserve,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let hasRiskModel = reserve::has_risk_model(reserve, get<T>());
    assert!(hasRiskModel == true, EIllegalCollateralType);
    
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      obligation: object::id(obligation),
      depositAsset: type_name::get<T>(),
      depositAmount: coin::value(&coin),
    });
  
    reserve::handle_add_collateral<T>(reserve, coin::value(&coin));
    obligation::deposit_collateral(obligation, coin::into_balance(coin))
  }
}
