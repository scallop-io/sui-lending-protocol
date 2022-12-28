module protocol::bank_vault {
  
  use sui::tx_context::TxContext;
  use sui::balance::Balance;
  use sui::object::{Self, UID};
  use x::supply_bag::{Self, SupplyBag};
  use x::balance_bag::{Self, BalanceBag};
  
  friend protocol::admin;
  friend protocol::repay;
  friend protocol::borrow;
  friend protocol::bank;
  
  struct BankCoin<phantom T> has drop {}
  
  struct BankVault has key, store {
    id: UID,
    bankCoinSupplies: SupplyBag,
    underlyingBalances: BalanceBag,
  }
  
  // create a vault for storing underlying assets and bank coin supplies
  public fun new(
    ctx: &mut TxContext
  ): BankVault {
    BankVault {
      id: object::new(ctx),
      bankCoinSupplies: supply_bag::new(ctx),
      underlyingBalances: balance_bag::new(ctx)
    }
  }
  
  public(friend) fun register_coin<T>(
    bankCoinWitness: BankCoin<T>,
    self: &mut BankVault
  ) {
    supply_bag::init_supply(bankCoinWitness, &mut self.bankCoinSupplies);
    balance_bag::init_balance<T>(&mut self.underlyingBalances)
  }
  
  public fun bank_coin_supply<T>(
    self: &BankVault
  ): u64 {
    supply_bag::supply_value<BankCoin<T>>(&self.bankCoinSupplies)
  }
  
  public fun deposit_underlying_coin<T>(
    self: &mut BankVault,
    balance: Balance<T>
  ) {
    balance_bag::join(&mut self.underlyingBalances, balance)
  }
  
  public(friend) fun withdraw_underlying_coin<T>(
    self: &mut BankVault,
    amount: u64
  ): Balance<T> {
    balance_bag::split<T>(&mut self.underlyingBalances, amount)
  }
  
  public(friend) fun issue_bank_coin<T>(
    self: &mut BankVault,
    amount: u64,
  ): Balance<BankCoin<T>> {
    supply_bag::increase_supply<BankCoin<T>>(&mut self.bankCoinSupplies, amount)
  }
  
  public(friend) fun burn_bank_coin<T>(
    self: &mut BankVault,
    balance: Balance<BankCoin<T>>
  ) {
    supply_bag::decrease_supply(&mut self.bankCoinSupplies, balance);
  }
}
