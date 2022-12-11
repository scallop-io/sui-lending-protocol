module mobius_core::position_table {
  
  use sui::object::{UID, ID};
  use mobius_core::position::{Position, PositionKey, key_to};
  use sui::object_table::ObjectTable;
  use sui::tx_context;
  use sui::object;
  use sui::object_table;
  use mobius_core::position;
  
  
  struct PositionTable has key {
    id: UID,
    table: ObjectTable<ID, Position>,
  }
  
  public fun new(ctx: &mut tx_context::TxContext): PositionTable {
    PositionTable {
      id: object::new(ctx),
      table: object_table::new(ctx)
    }
  }
  
  public fun new_position(self: &mut PositionTable, ctx: &mut tx_context::TxContext): PositionKey {
    let (position, key) = position::new(ctx);
    let positionId = object::id(&position);
    object_table::add(&mut self.table, positionId, position);
    key
  }
  
  public fun add_collateral<T>(self: &mut PositionTable, amount: u64, key: &PositionKey) {
    let position = object_table::borrow_mut(&mut self.table, key_to(key));
    position::add_collateral<T>(position, key, amount);
  }
  
  public fun remove_collateral<T>(self: &mut PositionTable, amount: u64, key: &PositionKey) {
    let position = object_table::borrow_mut(&mut self.table, key_to(key));
    position::remove_collateral<T>(position, key, amount);
  }
  
  public fun add_debt<T>(self: &mut PositionTable, amount: u64, key: &PositionKey) {
    let position = object_table::borrow_mut(&mut self.table, key_to(key));
    position::add_debt<T>(position, key, amount);
  }
  
  public fun remove_debt<T>(self: &mut PositionTable, amount: u64, key: &PositionKey) {
    let position = object_table::borrow_mut(&mut self.table, key_to(key));
    position::remove_debt<T>(position, key, amount);
  }
  
  public fun liquidate_collateral<T>(self: &mut PositionTable, amount: u64, positionAddr: address, ctx: &mut tx_context::TxContext) {
    let positionId = object::id_from_address(positionAddr);
    let position = object_table::borrow_mut(&mut self.table, positionId);
    position::liquidate_collateral<T>(position, amount, ctx);
  }
  
  public fun liquidate<T>(self: &mut PositionTable, positionAddr: address, ctx: &mut tx_context::TxContext) {
    let positionId = object::id_from_address(positionAddr);
    let position = object_table::borrow_mut(&mut self.table, positionId);
    position::liquidate<T>(position, ctx);
  }
}
