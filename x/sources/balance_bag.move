/**
In some cases, the app need to manage balances for different tokens in one place.
This module is created for this purpose.

It supports:
1. Put any type of balance into the bag
2. Retrieve, update the balances in the bag
*/
module x::balance_bag {
  use std::type_name::{Self, TypeName};
  use sui::bag::{Self, Bag};
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use sui::tx_context;
  
  struct BalanceBag has store {
    id: UID,
    bag: Bag,
  }
  
  public fun new(ctx: &mut tx_context::TxContext): BalanceBag {
    BalanceBag {
      id: object::new(ctx),
      bag: bag::new(ctx),
    }
  }
  
  public fun init_balance<T>(self: &mut BalanceBag) {
    let typeName = type_name::get<T>();
    bag::add(&mut self.bag, typeName, balance::zero<T>())
  }
  
  public fun join<T>(self: &mut BalanceBag, balance: Balance<T>) {
    let typeName = type_name::get<T>();
    let inBagBalance = bag::borrow_mut<TypeName, Balance<T>>(&mut self.bag, typeName);
    balance::join(inBagBalance, balance);
  }
  
  public fun split<T>(self: &mut BalanceBag, amount: u64): Balance<T> {
    let typeName = type_name::get<T>();
    let inBagBalance = bag::borrow_mut<TypeName, Balance<T>>(&mut self.bag, typeName);
    balance::split(inBagBalance, amount)
  }
  
  public fun value<T>(self: &BalanceBag): u64 {
    let typeName = type_name::get<T>();
    let inBagBalance = bag::borrow<TypeName, Balance<T>>(&self.bag, typeName);
    balance::value(inBagBalance)
  }
  
  public fun contains<T>(self: &BalanceBag): bool {
    let typeName = type_name::get<T>();
    bag::contains_with_type<TypeName, Balance<T>>(&self.bag, typeName)
  }
  
  public fun bag(self: &BalanceBag): &Bag {
    &self.bag
  }
  
  public fun destroy_empty(self: BalanceBag) {
    let BalanceBag { id, bag } = self;
    object::delete(id);
    bag::destroy_empty(bag);
  }
}
