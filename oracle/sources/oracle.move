/// TODO: implement real oracle using pyth data
module oracle::oracle {
  use std::type_name::{Self, TypeName};
  use sui::tx_context::TxContext;
  use sui::object::{UID, ID};
  use sui::object;
  use sui::transfer;
  use sui::table::{Self, Table};
  
  use oracle::price::{Self, Price};
  use oracle::i64;
  
  friend oracle::admin;
  
  struct Oracle<phantom T> has key {
    id: UID,
    price: Price,
  }
  
  struct OracleRegistry has key {
    id: UID,
    registryTable: Table<TypeName, ID>
  }
  
  // Make sure only one oracle per price pair
  // Also the registry serves as a oracle pair discovery entry
  fun register_oracle<T>(registry: &mut OracleRegistry, oracle: &Oracle<T>) {
    let oracleType = type_name::get<T>();
    table::add(&mut registry.registryTable, oracleType, object::id(oracle))
  }
  
  // Create a new oracle
  public(friend) entry fun create_oracle<T>(registry: &mut OracleRegistry, ctx: &mut TxContext) {
    let oracle = Oracle<T> {
      id: object::new(ctx),
      price: price::new(i64::from_u64(0), 0, i64::from_u64(0), 0),
    };
    register_oracle<T>(registry, &oracle);
    transfer::share_object(oracle)
  }
  
  // get the price from oracle
  // each price oracle will not compete with each other
  // For example: even if BTC/USD oracle object is busy, it will not affect SUI/USD
  public fun get_price<T>(oracle: &Oracle<T>): Price {
    oracle.price
  }
  
  // update price in oracle
  public entry fun update_price<T>(oracle: &Oracle<T>, priceValue: u64, expo: u64) {
    oracle.price = price::new(
      i64::from_u64(priceValue),
      0,
      i64::new(expo, true),
      0,
    );
  }
}
