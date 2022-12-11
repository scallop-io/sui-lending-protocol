module mobius_core::pool_bag {
  use mobius_core::pool::{Self, Pool};
  use sui::object::{Self, UID};
  use sui::object_bag::ObjectBag;
  use sui::tx_context;
  use sui::object_bag;
  use sui::coin::Coin;
  use std::type_name::{Self, TypeName};
  use sui::balance::Balance;
  
  struct PoolBag has key {
    id: UID,
    pools: ObjectBag,
    disabled: bool,
  }
  
  public fun create_pool_bag(ctx: &mut tx_context::TxContext): PoolBag {
    PoolBag {
      id: object::new(ctx),
      pools: object_bag::new(ctx),
      disabled: false
    }
  }
  
  public fun deposit<T>(self: &mut PoolBag, coin: Coin<T>, ctx: &mut tx_context::TxContext) {
    let pool = borrow_pool_mut<T>(self, ctx);
    pool::deposit(pool, coin)
  }
  
  public fun withdraw<T>(self: &mut PoolBag, amount: u64, ctx: &mut tx_context::TxContext): Balance<T> {
    let pool = borrow_pool_mut<T>(self, ctx);
    pool::withdraw(pool, amount)
  }
  
  fun init_pool_if_not_exist<T>(self: &mut PoolBag, ctx: &mut tx_context::TxContext) {
    let typeName = type_name::get<T>();
    let poolExists = object_bag::contains_with_type<TypeName, Pool<T>>(&self.pools, typeName);
    if (poolExists == false) {
      object_bag::add(&mut self.pools, typeName, pool::new<T>(ctx))
    }
  }
  
  fun borrow_pool_mut<T>(self: &mut PoolBag, ctx: &mut tx_context::TxContext): &mut Pool<T> {
    let typeName = type_name::get<T>();
    init_pool_if_not_exist<T>(self, ctx);
    object_bag::borrow_mut<TypeName, Pool<T>>(&mut self.pools, typeName)
  }
}
