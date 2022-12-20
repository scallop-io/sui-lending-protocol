module mobius_core::user_operation {
  
  use mobius_core::position::{Self, Position};
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::balance::Balance;
  use sui::tx_context::TxContext;
  use sui::transfer;
  
  struct RepayVault<phantom T> has key {
    id: UID,
    balance: Balance<T>,
  }
  
  /***
  Step 1:
    User first repay to the position to reduce debt,
    A shared object containing the repayed balance is generated
    
  Step 2:
    User then need to use the generated shared object to put fund back to bank
    
  We seperate the repay action into 2 steps, because:
  In step 1, user only need to interaction with their position and coin.
  This makes the transaction not compete with other user who's also interacting with protocol.
  In Sui blockchain, the less people who use the same shared object, the faster it gets confirmed.
  In some big market movement, repay in time is critical, so that can avoid being liquidated.
  
  For step 2, the shared object containing the fund can be returned to the bank by anyone.
  So it's pretty safe to do so. It doesn't have liveness problem
  */
  public entry fun repay<T>(position: &mut Position, coin: Coin<T>, ctx: &mut TxContext) {
    position::remove_debt<T>(position, coin::value(&coin));
    let repayVault = RepayVault {
      id: object::new(ctx),
      balance: coin::into_balance(coin)
    };
    transfer::share_object(repayVault)
  }
  
  
}
