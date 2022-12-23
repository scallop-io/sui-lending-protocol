// refactor position to better handle operations
module mobius_protocol::position {
  
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, UID};
  use sui::tx_context;
  use sui::balance::{Self, Balance};
  
  use math::exponential::Exp;
  use x::balance_bag::{Self, BalanceBag};
  use x::ownership::{Self, Ownership};
  use x::wit_table::{Self, WitTable};
  
  use mobius_protocol::position_debts::{Self, PositionDebts, Debt};
  use mobius_protocol::position_collaterals::{Self, PositionCollaterals, Collateral};
  
  friend mobius_protocol::repay;
  
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
  
  public(friend) fun withdraw_collateral<T>(
    self: &mut Position,
    amount: u64,
  ): Balance<T> {
    let typeName = type_name::get<T>();
    // reduce collateral amount
    let newCollateralAmount = collateral(self, typeName) - amount;
    position_collaterals::update_collateral(&mut self.collaterals, typeName, newCollateralAmount);
    // return the collateral balance
    balance_bag::split(&mut self.balances, amount)
  }
  
  public(friend) fun deposit_collateral<T>(
    self: &mut Position,
    balance: Balance<T>,
  ) {
    let typeName = type_name::get<T>();
    // increase collateral amount
    let newCollateralAmount = collateral(self, typeName) + balance::value(&balance);
    position_collaterals::update_collateral(&mut self.collaterals, typeName, newCollateralAmount);
    // take the collateral balance
    balance_bag::join(&mut self.balances, balance)
  }
  
  public (friend) fun update_debt(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
    borrowMark: Exp,
  ) {
    position_debts::update_debt(&mut self.debts, typeName, amount, borrowMark)
  }
  
  public(friend) fun update_debt_amount(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
    isIncrease: bool,
  ) {
    let (debtAmount, mark) = debt(self, typeName);
    let newDebtAmount = if(isIncrease) {
      debtAmount + amount
    } else {
      debtAmount - amount
    };
    position_debts::update_debt(&mut self.debts, typeName, newDebtAmount, mark)
  }
  
  public(friend) fun increase_debt(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
  ) {
    update_debt_amount(self, typeName, amount, true)
  }
  
  public(friend) fun decrease_debt(
    self: &mut Position,
    typeName: TypeName,
    amount: u64,
  ) {
    update_debt_amount(self, typeName, amount, false)
  }
  
  public fun debt(
    self: &Position,
    typeName: TypeName,
  ): (u64, Exp) {
    position_debts::debt(&self.debts, typeName)
  }
  
  public fun collateral(
    self: &Position,
    typeName: TypeName,
  ): u64 {
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
