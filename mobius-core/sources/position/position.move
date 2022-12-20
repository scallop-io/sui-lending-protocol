module mobius_core::position {
  
  use sui::object::{UID, ID};
  use sui::object;
  use sui::tx_context;
  use sui::balance::Balance;
  use std::option::Option;
  use std::option;
  
  use balance_bag::balance_bag::{Self, BalanceBag};
  use mobius_core::token_stats::{Self, TokenStats};
  
  friend mobius_core::core;
  friend mobius_core::bank;
  friend mobius_core::liquidator;
  friend mobius_core::user_operation;
  
  const EPositionKeyNotMatch: u64 = 0;
  const ENotLiquidator: u64 = 1;
  const ENotLiquidated: u64 = 2;
  const ELiquidated: u64 = 3;
  
  struct Position has key, store {
    id: UID,
    collaterals: BalanceBag,
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
    assert!(self.liquidated != true, ELiquidated);
    assert!(object::id(self) == key.to, EPositionKeyNotMatch)
  }
  
  fun assert_is_liquidator(self: &Position, ctx: &mut tx_context::TxContext) {
    assert!(self.liquidated == true, ENotLiquidated);
    let sender = tx_context::sender(ctx);
    let liquidator = option::borrow(&self.liquidator);
    assert!(*liquidator == sender, ENotLiquidator);
  }
  
  public (friend) fun new(ctx: &mut tx_context::TxContext): (Position, PositionKey) {
    let position = Position {
      id: object::new(ctx),
      collaterals: balance_bag::new(ctx),
      debts: token_stats::new(),
      liquidated: false,
      liquidator: option::none(),
    };
    let key = PositionKey {
      id: object::new(ctx),
      to: object::id(&position)
    };
    (position, key)
  }
  
  public (friend) fun add_collateral<T>(self: &mut Position, balance: Balance<T>) {
    balance_bag::join(&mut self.collaterals, balance);
  }
  
  public (friend) fun liquidate_collateral<T>(self: &mut Position, amount: u64, ctx: &mut tx_context::TxContext): Balance<T> {
    assert_is_liquidator(self, ctx);
    balance_bag::split<T>(&mut self.collaterals, amount)
  }
  
  /// TODO: check the health before remove collateral
  public (friend) fun remove_collateral<T>(self: &mut Position, key: &PositionKey, amount: u64): Balance<T> {
    assert_key_match(self, key);
    balance_bag::split<T>(&mut self.collaterals, amount)
  }
  
  /// TODO: check the health before add debt
  public (friend) fun add_debt<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::increase<T>(&mut self.debts, amount)
  }
  
  public (friend) fun remove_debt<T>(self: &mut Position, amount: u64) {
    token_stats::decrease<T>(&mut self.debts, amount)
  }
  
  public (friend) fun liquidate(self: &mut Position, ctx: &mut tx_context::TxContext) {
    self.liquidated = true;
    self.debts = token_stats::new();
    let sender = tx_context::sender(ctx);
    option::fill(&mut self.liquidator, sender);
  }
}
