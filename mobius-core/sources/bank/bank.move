module mobius_core::bank {
  use sui::object::{Self, UID};
  use sui::balance::{Self, Supply, Balance};
  use sui::tx_context::{TxContext};
  use mobius_core::bank_stats;
  use mobius_core::bank_stats::{BankStats};
  use math::exponential::Exp;
  use mobius_core::borrow_index::BorrowIndexTable;
  use mobius_core::borrow_index;
  use std::type_name;
  use math::exponential;
  use time::timestamp::TimeStamp;
  use mobius_core::interest_model::InterestModelTable;
  
  friend mobius_core::admin;
  friend mobius_core::user_operation;
  
  const EBankCoinInitialSupplyNotZero: u64 = 0;
  
  const INITIAL_EXCHANGE_RATE: u64 = 1;
  
  struct BankCoin<phantom T> has drop {}
  
  struct Bank<phantom T> has key, store {
    id: UID,
    bankCoinSupply: Supply<BankCoin<T>>,
    underlyingCashBalance: Balance<T>,
    underlyingLendAmount: u64,
    underlyingReserveBalance: Balance<T>,
    borrowIndex: Exp
  }
  
  // create a bank for underlying coin
  public(friend) fun new<T>(
    ctx: &mut TxContext
  ): Bank<T> {
    let bankCoinSupply = balance::create_supply( BankCoin {} );
    
    Bank {
      id: object::new(ctx),
      bankCoinSupply,
      underlyingCashBalance: balance::zero(),
      underlyingLendAmount: 0,
      underlyingReserveBalance: balance::zero(),
      borrowIndex: exponential::exp(0, 1)
    }
  }
  
  // deposit coin to get bankCoin
  public(friend) fun mint<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    borrowIndexTable: &mut BorrowIndexTable,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    underlyingBalance: Balance<T>,
  ): Balance<BankCoin<T>> {
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let bankBalance = mint_(self, underlyingBalance);
    update_bank_stats_(self, bankStats);
    bankBalance
  }
  
  // return bankCoin to get coin
  public(friend) fun redeem<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    borrowIndexTable: &mut BorrowIndexTable,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    bankCoinBalance: Balance<BankCoin<T>>,
  ): Balance<T> {
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let balance = redeem_(self, bankCoinBalance);
    update_bank_stats_(self, bankStats);
    balance
  }
  
  // borrow underlying coin from bank
  public(friend) fun borrow<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    borrowIndexTable: &mut BorrowIndexTable,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    amount: u64,
  ): Balance<T> {
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    let balance = borrow_(self, amount);
    update_bank_stats_(self, bankStats);
    balance
  }
  
  // borrow underlying coin from bank
  public(friend) fun repay<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    borrowIndexTable: &mut BorrowIndexTable,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
    underlyingBalance: Balance<T>,
  ) {
    accue_interest_(
      self,
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
    );
    repay_(self, underlyingBalance);
    update_bank_stats_(self, bankStats);
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun balance_sheet<T>(
    bank: &Bank<T>
  ): (u64, u64, u64) {
    let totalCash = balance::value(&bank.underlyingCashBalance);
    let totalLending = bank.underlyingLendAmount;
    let totalReserve = balance::value(&bank.underlyingReserveBalance);
    (totalLending, totalCash, totalReserve)
  }
  
  fun mint_<T>(
    bank: &mut Bank<T>,
    underlyingBalance: Balance<T>,
  ): Balance<BankCoin<T>> {
    // mint bank balance according to exchange rate
    let exchangeRate = cal_exchange_rate_(bank);
    let mintValue = exponential::mul_scalar_exp_truncate(
      (balance::value(&underlyingBalance) as u128),
      exchangeRate,
    );
    let mintValue = (mintValue as u64);
    let mintedBankCoinBalance = balance::increase_supply(&mut bank.bankCoinSupply, mintValue);
    
    // put underlying coin into bank cash
    balance::join(&mut bank.underlyingCashBalance, underlyingBalance);
    
    // return bankCoin balance
    mintedBankCoinBalance
  }
  
  fun redeem_<T>(
    bank: &mut Bank<T>,
    bankCoinBalance: Balance<BankCoin<T>>,
  ): Balance<T> {
    // withdraw balance from cash according to exchange rate
    let exchangeRate = cal_exchange_rate_(bank);
    let withdrawValue = exponential::div_scalar_by_exp_truncate(
      (balance::value(&bankCoinBalance) as u128),
      exchangeRate,
    );
    let withdrawValue = (withdrawValue as u64);
    let withdrawedUnderlyingBalance = balance::split(&mut bank.underlyingCashBalance, withdrawValue);
    
    // burn bank coin
    balance::decrease_supply(&mut bank.bankCoinSupply, bankCoinBalance);
    
    // return the underlying balance
    withdrawedUnderlyingBalance
  }
  
  fun borrow_<T>(
    bank: &mut Bank<T>,
    borrowAmount: u64,
  ): Balance<T> {
    // increase the lend amount
    bank.underlyingLendAmount = bank.underlyingLendAmount + borrowAmount;
    // take the balance from cash
    balance::split(&mut bank.underlyingCashBalance, borrowAmount)
  }
  
  fun repay_<T>(
    bank: &mut Bank<T>,
    underlyingBalance: Balance<T>,
  ) {
    // decrease the lend amount
    bank.underlyingLendAmount = bank.underlyingLendAmount - balance::value(&underlyingBalance);
    // return the coin to cash
    balance::join(&mut bank.underlyingCashBalance, underlyingBalance);
  }
  
  // collect debt interest and update borrow index
  fun accue_interest_<T>(
    bank: &mut Bank<T>,
    borrowIndexTable: &mut BorrowIndexTable,
    bankStats: &BankStats,
    timeOracle: &TimeStamp,
    interestModelTable: &InterestModelTable,
  ) {
    let typeName = type_name::get<T>();
    let newBorrowIndex = borrow_index::get(
      borrowIndexTable,
      bankStats,
      timeOracle,
      interestModelTable,
      typeName
    );
    let newDebt = exponential::mul_scalar_exp(
      exponential::div_exp(newBorrowIndex, bank.borrowIndex),
      (bank.underlyingLendAmount as u128)
    );
    bank.underlyingLendAmount = (exponential::truncate(newDebt) as u64);
    bank.borrowIndex = newBorrowIndex;
  }
  
  fun update_bank_stats_<T>(
    bank: &Bank<T>,
    bankStats: &mut BankStats,
  ) {
    bank_stats::update<T>(
      bankStats,
      bank.underlyingLendAmount,
      balance::value(&bank.underlyingCashBalance),
      balance::value(&bank.underlyingReserveBalance),
    );
  }
  
  fun cal_exchange_rate_<T>(
    bank: &Bank<T>
  ): Exp {
    let x = balance::value(&bank.underlyingCashBalance) + bank.underlyingLendAmount;
    let y = balance::supply_value(&bank.bankCoinSupply);
    exponential::exp((x as u128), (y as u128))
  }
}
