/**
In some cases, the app need to manage balances for different tokens in one place.
This module is created for this purpose.

It supports:
1. Put any type of balance into the bag
2. Retrieve, update the balances in the bag

By default, every operation will create a zero balance if not exist.
*/
module x::balance_bag {
  use sui::bag::{Self, Bag};
  use sui::tx_context;
  use std::type_name::{Self, TypeName};
  use sui::balance::{Self, Balance};
  
  struct BalanceBag has store {
    balances: Bag,
  }
  
  public fun new(ctx: &mut tx_context::TxContext): BalanceBag {
    BalanceBag {
      balances: bag::new(ctx),
    }
  }
  
  public fun join<T>(self: &mut BalanceBag, balance: Balance<T>) {
    let inBagBalance = borrow_balance_mut<T>(self);
    balance::join(inBagBalance, balance);
  }
  
  public fun split<T>(self: &mut BalanceBag, amount: u64): Balance<T> {
    let inBagBalance = borrow_balance_mut<T>(self);
    balance::split(inBagBalance, amount)
  }
  
  public fun remove<T>(self: &mut BalanceBag): Balance<T> {
    remove_balance<T>(self)
  }
  
  public fun destroy_empty(self: BalanceBag) {
    let BalanceBag { balances } = self;
    bag::destroy_empty(balances);
  }
  
  fun borrow_balance_mut<T>(self: &mut BalanceBag): &mut Balance<T> {
    let typeName = type_name::get<T>();
    init_balance_if_not_exist<T>(self);
    bag::borrow_mut<TypeName, Balance<T>>(&mut self.balances, typeName)
  }
  
  fun remove_balance<T>(self: &mut BalanceBag): Balance<T> {
    let typeName = type_name::get<T>();
    init_balance_if_not_exist<T>(self);
    bag::remove(&mut self.balances, typeName)
  }
  
  fun init_balance_if_not_exist<T>(self: &mut BalanceBag) {
    let typeName = type_name::get<T>();
    let balanceExists = bag::contains_with_type<TypeName, Balance<T>>(&self.balances, typeName);
    if (balanceExists == false) {
      bag::add(&mut self.balances, typeName, balance::zero<T>())
    }
  }
}
