module mobius_core::core {
  use mobius_core::pool_bag::{Self, PoolBag};
  use mobius_core::position_table::{Self, PositionTable};
  use sui::coin::{Self, Coin};
  use sui::tx_context;
  use mobius_core::position::PositionKey;
  use sui::transfer;
  
  public entry fun deposit<T>(
    poolBag: &mut PoolBag,
    positionTable: &mut PositionTable,
    positionKey: &PositionKey,
    coin: Coin<T>,
    ctx: &mut tx_context::TxContext) {
    position_table::add_collateral<T>(positionTable, coin::value(&coin), positionKey);
    pool_bag::deposit(poolBag, coin, ctx);
  }
  
  public entry fun withdraw<T>(
    poolBag: &mut PoolBag,
    positionTable: &mut PositionTable,
    positionKey: &PositionKey,
    amount: u64,
    ctx: &mut tx_context::TxContext) {
    position_table::remove_collateral<T>(positionTable, amount, positionKey);
    let withdrawed = pool_bag::withdraw<T>(poolBag, amount, ctx);
    transfer::transfer(
      coin::from_balance(withdrawed, ctx),
      tx_context::sender(ctx))
  }
  
  public entry fun repay<T>(
    poolBag: &mut PoolBag,
    positionTable: &mut PositionTable,
    positionKey: &PositionKey,
    coin: Coin<T>,
    ctx: &mut tx_context::TxContext) {
    position_table::remove_debt<T>(positionTable, coin::value(&coin), positionKey);
    pool_bag::deposit(poolBag, coin, ctx);
  }
  
  public entry fun borrow<T>(
    poolBag: &mut PoolBag,
    positionTable: &mut PositionTable,
    positionKey: &PositionKey,
    amount: u64,
    ctx: &mut tx_context::TxContext) {
    position_table::add_collateral<T>(positionTable, amount, positionKey);
    let borrowed = pool_bag::withdraw<T>(poolBag, amount, ctx);
    transfer::transfer(
      coin::from_balance(borrowed, ctx),
      tx_context::sender(ctx))
  }
  public entry fun extract_liquidation<T>(
    poolBag: &mut PoolBag,
    positionTable: &mut PositionTable,
    positionAddr: address,
    amount: u64,
    ctx: &mut tx_context::TxContext) {
    position_table::liquidate_collateral<T>(positionTable, amount, positionAddr, ctx);
    let liquidated = pool_bag::withdraw<T>(poolBag, amount, ctx);
    transfer::transfer(
      coin::from_balance(liquidated, ctx),
      tx_context::sender(ctx))
  }
  
  public entry fun liquidate<T>(
    positionTable: &mut PositionTable,
    postionAddr: address,
    ctx: &mut tx_context::TxContext) {
    position_table::liquidate<T>(positionTable, postionAddr, ctx);
  }
  
}
