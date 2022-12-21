module mobius_core::bank {
  use sui::object::{Self, UID};
  use sui::balance::{Self, Supply, Balance};
  use sui::tx_context::{TxContext};
  use mobius_core::bank_stats;
  use mobius_core::bank_stats::BankStats;
  
  friend mobius_core::admin;
  
  const EBankCoinInitialSupplyNotZero: u64 = 0;
  
  const INITIAL_EXCHANGE_RATE: u64 = 1;
  
  struct BankCoin<phantom T> has drop {}
  
  struct Bank<phantom T> has key, store {
    id: UID,
    bankCoinSupply: Supply<BankCoin<T>>,
    underlyingCashBalance: Balance<T>,
    underlyingLendAmount: u64,
    underlyingReserveBalance: Balance<T>,
    lastUpdatedTimestamp: u64
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
      lastUpdatedTimestamp: 0
    }
  }
  
  // deposit coin to get bankCoin
  public(friend) fun mint<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    underlyingBalance: Balance<T>,
  ): Balance<BankCoin<T>> {
    let bankBalance = mint_(self, underlyingBalance);
    bank_stats::update(bankStats, self);
    bankBalance
  }
  
  // return bankCoin to get coin
  public(friend) fun redeem<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    bankCoinBalance: Balance<BankCoin<T>>,
  ): Balance<T> {
    let balance = redeem_(self, bankCoinBalance);
    bank_stats::update(bankStats, self);
    balance
  }
  
  // borrow underlying coin from bank
  public(friend) fun borrow<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    amount: u64,
  ): Balance<T> {
    let balance = borrow_(self, amount);
    bank_stats::update(bankStats, self);
    balance
  }
  
  // borrow underlying coin from bank
  public(friend) fun repay<T>(
    self: &mut Bank<T>,
    bankStats: &mut BankStats,
    underlyingBalance: Balance<T>,
  ) {
    repay_(self, underlyingBalance);
    bank_stats::update(bankStats, self);
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
  
  public fun last_updated<T>(
    bank: &Bank<T>
  ): u64 {
    bank.lastUpdatedTimestamp
  }
  
  fun mint_<T>(
    bank: &mut Bank<T>,
    underlyingBalance: Balance<T>,
  ): Balance<BankCoin<T>> {
    // mint bank balance according to exchange rate
    let exchangeRate = cal_exchange_rate_(bank);
    /// TODO: the math needs to be adjusted to handle floating numbers
    let mintValue = balance::value(&underlyingBalance) * exchangeRate;
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
    /// TODO: the math needs to be adjusted to handle floating numbers
    let withdrawValue = balance::value(&bankCoinBalance) / exchangeRate;
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
  
  fun cal_exchange_rate_<T>(
    bank: &Bank<T>
  ): u64 {
    let x = balance::value(&bank.underlyingCashBalance) + bank.underlyingLendAmount;
    let y = balance::supply_value(&bank.bankCoinSupply);
    x / y
  }
}
