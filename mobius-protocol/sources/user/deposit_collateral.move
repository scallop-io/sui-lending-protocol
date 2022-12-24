// Add collateral is extremely simple
// It's the big advantages of the protocol
// When you add collateral, you only interact with your own position
// So even the protocol is in a busy traffic,
// Add collateral is still fast
module mobius_protocol::deposit_collateral {
  
  use sui::coin::{Self, Coin};
  use mobius_protocol::position::{Self, Position};
  
  public entry fun add_collateral<T>(
    position: &mut Position,
    coin: Coin<T>,
  ) {
    position::deposit_collateral(position, coin::into_balance(coin))
  }
}
