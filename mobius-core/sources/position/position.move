module mobius_core::position {
  
  use sui::object::{UID, ID};
  use sui::object;
  use sui::tx_context;
  use sui::balance::{Self, Balance};
  
  use balance_bag::balance_bag::{Self, BalanceBag};
  use mobius_core::token_stats::{Self, TokenStats};
  use math::exponential::Exp;
  
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
    balances: BalanceBag,
    collaterals: TokenStats,
    debts: TokenStats,
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
  
  public (friend) fun new(ctx: &mut tx_context::TxContext): (Position, PositionKey) {
    let position = Position {
      id: object::new(ctx),
      balances: balance_bag::new(ctx),
      collaterals: token_stats::new(),
      debts: token_stats::new(),
    };
    let key = PositionKey {
      id: object::new(ctx),
      to: object::id(&position)
    };
    (position, key)
  }
  
  public (friend) fun add_collateral<T>(self: &mut Position, balance: Balance<T>) {
    token_stats::increase<T>(&mut self.collaterals, balance::value(&balance));
    balance_bag::join(&mut self.balances, balance);
  }
  
  /// TODO: check the health before remove collateral
  public (friend) fun remove_collateral<T>(self: &mut Position, key: &PositionKey, amount: u64): Balance<T> {
    assert_key_match(self, key);
    balance_bag::split<T>(&mut self.balances, amount)
  }
  
  /// TODO: check the health before add debt
  public (friend) fun add_debt<T>(self: &mut Position, key: &PositionKey, amount: u64) {
    assert_key_match(self, key);
    token_stats::increase<T>(&mut self.debts, amount)
  }
  
  public (friend) fun remove_debt<T>(self: &mut Position, amount: u64) {
    token_stats::decrease<T>(&mut self.debts, amount)
  }
  
  public fun debts(self: &Position): &TokenStats {
    &self.debts
  }
  
  public fun collaterals(self: &Position): &TokenStats {
    &self.collaterals
  }
}
