module mobius_protocol::bank {
  
  use sui::tx_context::TxContext;
  use sui::object::{Self, UID};
  use sui::balance::{Self, Supply, Balance};
  
  friend mobius_protocol::admin;
  friend mobius_protocol::repay;
  
  struct BankCoin<phantom T> has drop {}
  
  struct Bank<phantom T> has key, store {
    id: UID,
    bankCoinSupply: Supply<BankCoin<T>>,
    underlyingBalance: Balance<T>,
  }
  
  // create a bank for underlying coin
  public(friend) fun new<T>(
    ctx: &mut TxContext
  ): Bank<T> {
    let bankCoinSupply = balance::create_supply(BankCoin {});
    
    Bank {
      id: object::new(ctx),
      bankCoinSupply,
      underlyingBalance: balance::zero(),
    }
  }
  
  public(friend) fun issue_bank_coin<T>(
    self: &mut Bank<T>,
    amount: u64,
  ): Balance<BankCoin<T>> {
    balance::increase_supply(&mut self.bankCoinSupply, amount)
  }
  
  public(friend) fun burn_bank_coin<T>(
    self: &mut Bank<T>,
    balance: Balance<BankCoin<T>>
  ) {
    balance::decrease_supply(&mut self.bankCoinSupply, balance);
  }
  
  public(friend) fun deposit_underlying_coin<T>(
    self: &mut Bank<T>,
    balance: Balance<T>
  ) {
    balance::join(&mut self.underlyingBalance, balance);
  }
  
  public(friend) fun withdraw_underlying_coin<T>(
    self: &mut Bank<T>,
    amount: u64
  ): Balance<T> {
    balance::split(&mut self.underlyingBalance, amount)
  }
}
