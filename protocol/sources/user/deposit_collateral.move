module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName, get};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  
  const EIllegalCollateralType: u64 = 0x20001;
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    obligation: ID,
    deposit_asset: TypeName,
    deposit_amount: u64,
  }
  
  public entry fun deposit_collateral<T>(
    obligation: &mut Obligation,
    market: &mut Market,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    let has_risk_model = market::has_risk_model(market, get<T>());
    assert!(has_risk_model == true, EIllegalCollateralType);
    
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      obligation: object::id(obligation),
      deposit_asset: type_name::get<T>(),
      deposit_amount: coin::value(&coin),
    });
  
    market::handle_add_collateral<T>(market, coin::value(&coin));
    obligation::deposit_collateral(obligation, coin::into_balance(coin))
  }
}
