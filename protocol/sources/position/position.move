// refactor position to better handle operations
module protocol::position {
  
  use std::type_name::{Self, TypeName};
  use std::vector;
  use sui::object::{Self, UID};
  use sui::tx_context;
  use sui::balance::{Self, Balance};
  
  use x::balance_bag::{Self, BalanceBag};
  use x::ownership::{Self, Ownership};
  use x::wit_table::{Self, WitTable};
  
  use math::fr::Fr;
  
  use protocol::position_debts::{Self, PositionDebts, Debt};
  use protocol::position_collaterals::{Self, PositionCollaterals, Collateral};
  use protocol::bank::{Self, Bank};
  
  friend protocol::repay;
  friend protocol::borrow;
  friend protocol::deposit_collateral;
  friend protocol::withdraw_collateral;
  friend protocol::liquidate;
  
  const EWithdrawTooMuch: u64 = 0;
  const EBorrowTooMuch: u64 = 1;
  
  struct Position has key, store {
    id: UID,
    balances: BalanceBag,
    debts: WitTable<PositionDebts, TypeName, Debt>,
    collaterals: WitTable<PositionCollaterals, TypeName, Collateral>
  }
  
  struct PositionOwnership has drop {}
  
  struct PositionKey has key, store {
    id: UID,
    ownership: Ownership<PositionOwnership>
  }
  
  public (friend) fun new(ctx: &mut tx_context::TxContext): (Position, PositionKey) {
    let position = Position {
      id: object::new(ctx),
      balances: balance_bag::new(ctx),
      debts: position_debts::new(ctx),
      collaterals: position_collaterals::new(ctx),
    };
    let positionOwnership = ownership::create_ownership(
      PositionOwnership{},
      object::id(&position),
      ctx
    );
    let positionKey = PositionKey {
      id: object::new(ctx),
      ownership: positionOwnership,
    };
    (position, positionKey)
  }
  
  public(friend) fun accrue_interests(
    position: &mut Position,
    bank: &Bank,
  ) {
    let debtTypes = debt_types(position);
    let (i, n) = (0, vector::length(&debtTypes));
    while (i < n) {
      let type = *vector::borrow(&debtTypes, i);
      let newBorrowIndex = bank::borrow_index(bank, type);
      position_debts::accure_interest(&mut position.debts, type, newBorrowIndex);
      i = i + 1;
    };
  }
  
  public(friend) fun withdraw_collateral<T>(
    self: &mut Position,
    amount: u64,
  ): Balance<T> {
    let typeName = type_name::get<T>();
    // reduce collateral amount
    position_collaterals::decrease(&mut self.collaterals, typeName, amount);
    // return the collateral balance
    balance_bag::split(&mut self.balances, amount)
  }
  
  public fun deposit_collateral<T>(
    self: &mut Position,
    balance: Balance<T>,
  ) {
    // increase collateral amount
    let typeName = type_name::get<T>();
    position_collaterals::increase(&mut self.collaterals, typeName, balance::value(&balance));
    // put the collateral balance
    balance_bag::join(&mut self.balances, balance);
  }
  
  public(friend) fun init_debt(
    self: &mut Position,
    bank: &Bank,
    typeName: TypeName,
  ) {
    let borrowIndex = bank::borrow_index(bank, typeName);
    position_debts::init_debt(&mut self.debts, typeName, borrowIndex);
  }
  
  public(friend) fun increase_debt(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
  ) {
    position_debts::increase(&mut self.debts, typeName, amount);
  }
  
  public(friend) fun decrease_debt(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
  ) {
    position_debts::decrease(&mut self.debts, typeName, amount);
  }
  
  public fun debt(self: &Position, typeName: TypeName): (u64, Fr) {
    position_debts::debt(&self.debts, typeName)
  }
  
  public fun collateral(self: &Position, typeName: TypeName): u64 {
    position_collaterals::collateral(&self.collaterals, typeName)
  }
  
  // return the debt types
  public fun debt_types(self: &Position): vector<TypeName> {
    wit_table::keys(&self.debts)
  }
  
  // return the collateral types
  public fun collateral_types(self: &Position): vector<TypeName> {
    wit_table::keys(&self.collaterals)
  }
}
