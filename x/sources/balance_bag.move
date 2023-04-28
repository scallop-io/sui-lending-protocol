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
    let type_name = type_name::get<T>();
    let in_bag_balance = bag::borrow_mut<TypeName, Balance<T>>(&mut self.bag, type_name);
    balance::join(in_bag_balance, balance);
  }
  
  public fun split<T>(self: &mut BalanceBag, amount: u64): Balance<T> {
    let type_name = type_name::get<T>();
    let in_bag_balance = bag::borrow_mut<TypeName, Balance<T>>(&mut self.bag, type_name);
    balance::split(in_bag_balance, amount)
  }
  
  public fun value<T>(self: &BalanceBag): u64 {
    let type_name = type_name::get<T>();
    let in_bag_balance = bag::borrow<TypeName, Balance<T>>(&self.bag, type_name);
    balance::value(in_bag_balance)
  }
  
  public fun contains<T>(self: &BalanceBag): bool {
    let type_name = type_name::get<T>();
    bag::contains_with_type<TypeName, Balance<T>>(&self.bag, type_name)
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
