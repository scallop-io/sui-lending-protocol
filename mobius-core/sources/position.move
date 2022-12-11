module mobius_core::position {
  
  use sui::object::{UID, ID};
  use mobius_core::token_stats::{Self, TokenStats};
  use sui::object;
  use sui::tx_context;
  use std::option::Option;
  use std::option;
  
  const EPositionKeyNotMatch: u64 = 0;
  const ENotLiquidator: u64 = 1;
  const ENotLiquidated: u64 = 2;
  
  struct Position has key, store {
    id: UID,
    collaterals: TokenStats,
    debts: TokenStats,
    liquidated: bool,
    liquidator: Option<address>,
  }
  
  struct PositionKey has key, store {
    id: UID,
    to: ID,
  }
  
  public fun key_to(key: &PositionKey): ID {
    key.to
  }
  
  fun assert_key_match(self: &Position, key: &PositionKey) {
    assert!(object::id(self) == key.to, EPositionKeyNotMatch)
  }
  
  fun assert_is_liquidator(self: &Position, ctx: &mut tx_context::TxContext) {
    let sender = tx_context::sender(ctx);
    assert!(option::is_some(&self.liquidator), ENotLiquidated);
    let liquidator = option::borrow(&self.liquidator);
    assert!(*liquidator == sender, ENotLiquidator);
  }
  
  public fun new(ctx: &mut tx_context::TxContext): (Position, PositionKey) {
    let collaterals = token_stats::new();
    let debts = token_stats::new();
    let position = Position {
      id: object::new(ctx),
      collaterals,
      debts,
      liquidated: false,
      liquidator: option::none(),
    };
    let key = PositionKey {
      id: object::new(ctx),
      to: object::id(&position)
    };
    (position, key)
  }
  
  public fun add_collateral<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::increase<T>(&mut self.collaterals, amount)
  }
  
  public fun liquidate_collateral<T>(self: &mut Position, amount: u64, ctx: &mut tx_context::TxContext) {
    assert_is_liquidator(self, ctx);
    token_stats::decrease<T>(&mut self.collaterals, amount)
  }
  
  public fun remove_collateral<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::decrease<T>(&mut self.collaterals, amount)
  }
  
  public fun add_debt<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::increase<T>(&mut self.debts, amount)
  }
  
  public fun remove_debt<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::decrease<T>(&mut self.debts, amount)
  }
  
  public fun liquidate<T>(self: &mut Position, ctx: &mut tx_context::TxContext) {
    self.liquidated = true;
    self.debts = token_stats::new();
    let sender = tx_context::sender(ctx);
    option::fill(&mut self.liquidator, sender);
  }
}
