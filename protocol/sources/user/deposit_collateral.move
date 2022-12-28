// Add collateral is extremely simple
// It's the big advantages of the protocol
// When you add collateral, you only interact with your own position
// So even the protocol is in a busy traffic,
// Add collateral is still fast
module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::position::{Self, Position};
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    position: ID,
    depositAsset: TypeName,
    depositAmount: u64,
  }
  
  public entry fun add_collateral<T>(
    position: &mut Position,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      position: object::id(position),
      depositAsset: type_name::get<T>(),
      depositAmount: coin::value(&coin),
    });
    
    position::deposit_collateral(position, coin::into_balance(coin))
  }
}
