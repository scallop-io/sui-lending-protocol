module x::supply_bag {
  use std::type_name::{Self, TypeName};
  use sui::tx_context::TxContext;
  use sui::bag::{Self ,Bag};
  use sui::balance::{Self, Balance, Supply};
  use sui::object::{Self, UID};
  
  struct SupplyBag has store {
    id: UID,
    bag: Bag
  }
  
  public fun new(ctx: &mut TxContext): SupplyBag {
    SupplyBag {
      id: object::new(ctx),
      bag: bag::new(ctx)
    }
  }
  
  public fun init_supply<T: drop>(witness: T, self: &mut SupplyBag) {
    let type_name = type_name::get<T>();
    bag::add(&mut self.bag, type_name, balance::create_supply(witness))
  }
  
  public fun increase_supply<T>(self: &mut SupplyBag, amount: u64): Balance<T> {
    let type_name = type_name::get<T>();
    let supply = bag::borrow_mut<TypeName, Supply<T>>(&mut self.bag, type_name);
    balance::increase_supply(supply, amount)
  }
  
  public fun decrease_supply<T>(self: &mut SupplyBag, balance: Balance<T>): u64 {
    let type_name = type_name::get<T>();
    let supply = bag::borrow_mut<TypeName, Supply<T>>(&mut self.bag, type_name);
    balance::decrease_supply(supply, balance)
  }
  
  public fun supply_value<T>(self: &SupplyBag): u64 {
    let type_name = type_name::get<T>();
    let supply = bag::borrow<TypeName, Supply<T>>(&self.bag, type_name);
    balance::supply_value(supply)
  }
  
  public fun contains<T>(self: &SupplyBag): bool {
    let type_name = type_name::get<T>();
    bag::contains(&self.bag, type_name)
  }
  
  public fun bag(self: &SupplyBag): &Bag {
    &self.bag
  }
  
  public fun destroy_empty(self: SupplyBag) {
    let SupplyBag {id, bag} = self;
    object::delete(id);
    bag::destroy_empty(bag);
  }
}
