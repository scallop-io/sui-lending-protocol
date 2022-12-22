module mobius_core::position {
  
  use sui::object::{UID, ID};
  use sui::object;
  use sui::tx_context;
  use sui::balance::{Self, Balance};
  
  use balance_bag::balance_bag::{Self, BalanceBag};
  use mobius_core::token_stats::{Self, TokenStats};
  use mobius_core::borrow_index::BorrowIndexTable;
  use sui::table::Table;
  use std::type_name::TypeName;
  use math::exponential::Exp;
  use sui::table;
  use std::vector;
  use mobius_core::borrow_index;
  use math::exponential;
  use std::type_name;
  use mobius_core::bank_stats::BankStats;
  use time::timestamp::TimeStamp;
  use mobius_core::interest_model::InterestModelTable;
  use mobius_core::evaluator;
  use mobius_core::collateral_config::CollateralConfig;
  
  friend mobius_core::user_operation;
  
  const EPositionKeyNotMatch: u64 = 0;
  const EWithdrawTooMuch: u64 = 1;
  const EBorrowTooMuch: u64 = 2;
  
  struct Position has key, store {
    id: UID,
    balances: BalanceBag,
    collaterals: TokenStats,
    debts: TokenStats,
    borrowIndexes: Table<TypeName, Exp>
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
      borrowIndexes: table::new(ctx),
    };
    let key = PositionKey {
      id: object::new(ctx),
      to: object::id(&position)
    };
    (position, key)
  }
  
  public (friend) fun add_collateral<T>(
    self: &mut Position,
    balance: Balance<T>
  ) {
    let typeName = type_name::get<T>();
    token_stats::increase(&mut self.collaterals, typeName, balance::value(&balance));
    balance_bag::join(&mut self.balances, balance);
  }
  
  public (friend) fun remove_collateral<T>(
    self: &mut Position,
    key: &PositionKey,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    collateralConfig: &CollateralConfig,
    amount: u64
  ): Balance<T> {
    assert_key_match(self, key);
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let maxWithdrawAmount = evaluator::max_withdraw_amount<T>(
      &self.collaterals,
      &self.debts,
      collateralConfig
    );
    assert!(amount <= maxWithdrawAmount, EWithdrawTooMuch);
    balance_bag::split<T>(&mut self.balances, amount)
  }
  
  /// TODO: check the health before add debt
  public (friend) fun add_debt<T>(
    self: &mut Position,
    key: &PositionKey,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    collateralConfig: &CollateralConfig,
    amount: u64
  ) {
    assert_key_match(self, key);
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let maxBorrowAmount = evaluator::max_borrow_amount<T>(
      &self.collaterals,
      &self.debts,
      collateralConfig
    );
    assert!(amount <= maxBorrowAmount, EBorrowTooMuch);
    let typeName = type_name::get<T>();
    token_stats::increase(&mut self.debts, typeName, amount)
  }
  
  public (friend) fun remove_debt<T>(
    self: &mut Position,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    amount: u64
  ) {
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let typeName = type_name::get<T>();
    token_stats::decrease(&mut self.debts, typeName, amount)
  }
  
  public fun debts(self: &Position): &TokenStats {
    &self.debts
  }
  
  public fun collaterals(self: &Position): &TokenStats {
    &self.collaterals
  }
  
  fun accue_interest_(
    self: &mut Position,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
  ) {
    let debts = token_stats::stats(&self.debts);
    let newDebtStats = token_stats::new();
    let (i, n) = (0, vector::length(debts));
    while(i < n) {
      let debt = vector::borrow(debts, i);
      let debtType = token_stats::token_type(debt);
      let debtAmount = (token_stats::token_amount(debt) as u128);
      let debtBorrowIndex = table::borrow(&self.borrowIndexes, debtType);
      let currentBorrowIndex = borrow_index::get(
        borrowIndexTable,
        bankStats,
        timeOracle,
        interestModelTable,
        debtType
      );
      let newDebtAmount = exponential::mul_scalar_exp_truncate(
        debtAmount,
        exponential::div_exp(currentBorrowIndex, *debtBorrowIndex)
      );
      let debtInterest = ((newDebtAmount - debtAmount) as u64);
      token_stats::increase(&mut newDebtStats, debtType, debtInterest);
      i = i + 1;
    };
    self.debts = newDebtStats;
  }
}
