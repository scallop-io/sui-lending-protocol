module mobius_core::bank {
  use sui::object::{Self, UID};
  use sui::coin::{Self, TreasuryCap};
  use sui::balance::{Self, Supply, Balance};
  use sui::tx_context::{TxContext};
  
  friend mobius_core::admin;
  
  const EBankCoinInitialSupplyNotZero: u64 = 0;
  
  const INITIAL_EXCHANGE_RATE: u64 = 1;
  
  struct Bank<phantom UnderlyingCoin, phantom BankCoin> has key, store {
    id: UID,
    bankCoinSupply: Supply<BankCoin>,
    underlyingCashBalance: Balance<UnderlyingCoin>,
    underlyingLendAmount: u64,
    underlyingReserveBalance: Balance<UnderlyingCoin>,
  }
  
  // create a bank for underlying coin
  public(friend) fun new<UnderlyingCoin, BankCoin: drop>(
    bankCoinTreasuryCap: TreasuryCap<BankCoin>,
    ctx: &mut TxContext
  ): Bank<UnderlyingCoin, BankCoin> {
    // We ask for treasuryCap, in order to make sure it's created from create_currency
    let bankCoinSupply = coin::treasury_into_supply(bankCoinTreasuryCap);
    
    // The bank coin must have 0 supply, when creating bank
    assert!(balance::supply_value(&bankCoinSupply) == 0, EBankCoinInitialSupplyNotZero);
    
    Bank {
      id: object::new(ctx),
      bankCoinSupply,
      underlyingCashBalance: balance::zero(),
      underlyingLendAmount: 0,
      underlyingReserveBalance: balance::zero(),
    }
  }
  
  // deposit coin to get bankCoin
  public(friend) fun mint<UnderlyingCoin, BankCoin>(
    coinBank: &mut Bank<UnderlyingCoin, BankCoin>,
    underlyingBalance: Balance<UnderlyingCoin>,
  ): Balance<BankCoin> {
    mint_(coinBank, underlyingBalance)
  }
  
  // return bankCoin to get coin
  public(friend) fun redeem<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    bankCoinBalance: Balance<BankCoin>,
  ): Balance<UnderlyingCoin> {
    redeem_(bank, bankCoinBalance)
  }
  
  // borrow underlying coin from bank
  public(friend) fun borrow<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    amount: u64,
  ): Balance<UnderlyingCoin> {
    borrow_(bank, amount)
  }
  
  // borrow underlying coin from bank
  public(friend) fun repay<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    underlyingBalance: Balance<UnderlyingCoin>,
  ) {
    repay_(bank, underlyingBalance)
  }
  
  fun mint_<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    underlyingBalance: Balance<UnderlyingCoin>,
  ): Balance<BankCoin> {
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
  
  fun redeem_<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    bankCoinBalance: Balance<BankCoin>,
  ): Balance<UnderlyingCoin> {
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
  
  fun borrow_<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    borrowAmount: u64,
  ): Balance<UnderlyingCoin> {
    // increase the lend amount
    bank.underlyingLendAmount = bank.underlyingLendAmount + borrowAmount;
    // take the balance from cash
    balance::split(&mut bank.underlyingCashBalance, borrowAmount)
  }
  
  fun repay_<UnderlyingCoin, BankCoin>(
    bank: &mut Bank<UnderlyingCoin, BankCoin>,
    underlyingBalance: Balance<UnderlyingCoin>,
  ) {
    // decrease the lend amount
    bank.underlyingLendAmount = bank.underlyingLendAmount - balance::value(&underlyingBalance);
    // return the coin to cash
    balance::join(&mut bank.underlyingCashBalance, underlyingBalance);
  }
  
  fun cal_exchange_rate_<UnderlyingCoin, BankCoin>(
    bank: &Bank<UnderlyingCoin, BankCoin>
  ): u64 {
    let x = balance::value(&bank.underlyingCashBalance) + bank.underlyingLendAmount;
    let y = balance::supply_value(&bank.bankCoinSupply);
    x / y
  }
}
