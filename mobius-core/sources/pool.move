module mobius_core::pool {
  
  use sui::object::UID;
  use sui::balance::Balance;
  use sui::tx_context;
  use sui::object;
  use sui::balance;
  use sui::coin::{Self, Coin};
  
  struct Pool<phantom T> has key, store {
    id: UID,
    balance: Balance<T>,
    disabled: bool,
  }
  
  public fun new<T>(ctx: &mut tx_context::TxContext): Pool<T> {
    Pool {
      id: object::new(ctx),
      balance: balance::zero(),
      disabled: false
    }
  }
  
  public fun deposit<T>(self: &mut Pool<T>, coin: Coin<T>) {
    balance::join(&mut self.balance, coin::into_balance(coin));
  }
  
  public fun withdraw<T>(self: &mut Pool<T>, amount: u64): Balance<T> {
    balance::split(&mut self.balance, amount)
  }
}
