module protocol::bank_vault {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use x::supply_bag::{Self, SupplyBag};
  use x::balance_bag::{Self, BalanceBag};
  use x::wit_table::{Self, WitTable};
  use math::u64;
  
  friend protocol::bank;
  
  const EFlashLoanNotPaidEnough: u64 = 0;
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has copy, store {
    cash: u64,
    debt: u64,
    reserve: u64,
    bankCoinSupply: u64,
  }
  
  struct FlashLoan<phantom T> {
    amount: u64
  }
  
  struct BankCoin<phantom T> has drop {}
  
  struct BankVault has key, store {
    id: UID,
    bankCoinSupplies: SupplyBag,
    underlyingBalances: BalanceBag,
    balanceSheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
  }
  
  public fun bank_coin_supplies(vault: &BankVault): &SupplyBag { &vault.bankCoinSupplies }
  public fun underlying_balances(vault: &BankVault): &BalanceBag { &vault.underlyingBalances }
  public fun balance_sheets(vault: &BankVault): &WitTable<BalanceSheets, TypeName, BalanceSheet> { &vault.balanceSheets }
  
  public fun balance_sheet(balanceSheet: &BalanceSheet): (u64, u64, u64, u64) {
    (balanceSheet.cash, balanceSheet.debt, balanceSheet.reserve, balanceSheet.bankCoinSupply)
  }
  
  // create a vault for storing underlying assets and bank coin supplies
  public(friend) fun new(ctx: &mut TxContext): BankVault {
    BankVault {
      id: object::new(ctx),
      bankCoinSupplies: supply_bag::new(ctx),
      underlyingBalances: balance_bag::new(ctx),
      balanceSheets: wit_table::new(BalanceSheets{}, true, ctx),
    }
  }
  
  public(friend) fun register_coin<T>(self: &mut BankVault) {
    supply_bag::init_supply(BankCoin<T> {}, &mut self.bankCoinSupplies);
    balance_bag::init_balance<T>(&mut self.underlyingBalances);
    let balanceSheet = BalanceSheet { cash: 0, debt: 0, reserve: 0, bankCoinSupply: 0 };
    wit_table::add(BalanceSheets{}, &mut self.balanceSheets, get<T>(), balanceSheet);
  }
  
  public fun ulti_rate(self: &BankVault, typeName: TypeName): FixedPoint32 {
    let balanceSheet = wit_table::borrow(&self.balanceSheets, typeName);
    if (balanceSheet.debt > 0)  {
      fixed_point32::create_from_rational(balanceSheet.debt, balanceSheet.debt + balanceSheet.cash)
    } else {
      fixed_point32::create_from_rational(0, 1)
    }
  }
  
  public fun asset_types(self: &BankVault): vector<TypeName> {
    wit_table::keys(&self.balanceSheets)
  }
  
  public(friend) fun increase_debt(
    self: &mut BankVault,
    debtType: TypeName,
    debtIncreaseRate: FixedPoint32, // How much debt should be increased in percent, such as 0.05%
    reserveFactor: FixedPoint32,
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, debtType);
    let debtIncreased = fixed_point32::multiply_u64(balanceSheet.debt, debtIncreaseRate);
    let reserveIncreased = fixed_point32::multiply_u64(debtIncreased, reserveFactor);
    balanceSheet.debt = balanceSheet.debt + debtIncreased;
    balanceSheet.reserve = balanceSheet.reserve + reserveIncreased;
  }
  
  public(friend) fun deposit_underlying_coin<T>(
    self: &mut BankVault,
    balance: Balance<T>
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash + balance::value(&balance);
    balance_bag::join(&mut self.underlyingBalances, balance)
  }
  
  public(friend) fun withdraw_underlying_coin<T>(
    self: &mut BankVault,
    amount: u64
  ): Balance<T> {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash - amount;
    balance_bag::split<T>(&mut self.underlyingBalances, amount)
  }
  
  public(friend) fun mint_bank_coin<T>(
    self: &mut BankVault,
    underlyingBalance: Balance<T>,
  ): Balance<BankCoin<T>> {
    let underlyingAmount = balance::value(&underlyingBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let mintAmount = if (balanceSheet.bankCoinSupply > 0) {
      u64::mul_div(underlyingAmount, balanceSheet.bankCoinSupply, balanceSheet.cash + balanceSheet.debt)
    } else {
      underlyingAmount
    };
    balanceSheet.cash = balanceSheet.cash + underlyingAmount;
    balanceSheet.bankCoinSupply = balanceSheet.bankCoinSupply + mintAmount;
    balance_bag::join(&mut self.underlyingBalances, underlyingBalance);
    supply_bag::increase_supply<BankCoin<T>>(&mut self.bankCoinSupplies, mintAmount)
  }
  
  public(friend) fun redeem_underlying_coin<T>(
    self: &mut BankVault,
    bankCoinBalance: Balance<BankCoin<T>>,
  ): Balance<T> {
    let bankCoinAmount = balance::value(&bankCoinBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let redeemAmount = u64::mul_div(
      bankCoinAmount, balanceSheet.cash + balanceSheet.debt, balanceSheet.bankCoinSupply
    );
    balanceSheet.cash = balanceSheet.cash - redeemAmount;
    balanceSheet.bankCoinSupply = balanceSheet.bankCoinSupply - bankCoinAmount;
    supply_bag::decrease_supply(&mut self.bankCoinSupplies, bankCoinBalance);
    balance_bag::split<T>(&mut self.underlyingBalances, redeemAmount)
  }
  
  public fun borrow_flash_loan<T>(
    self: &mut BankVault,
    amount: u64
  ): (Balance<T>, FlashLoan<T>) {
    let balance = balance_bag::split<T>(&mut self.underlyingBalances, amount);
    let flashLoan = FlashLoan<T> { amount };
    (balance, flashLoan)
  }
  
  public fun return_flash_loan<T>(
    self: &mut BankVault,
    balance: Balance<T>,
    flashLoan: FlashLoan<T>,
  ) {
    let FlashLoan { amount } = flashLoan;
    assert!(balance::value(&balance) >= amount, EFlashLoanNotPaidEnough);
    balance_bag::join(&mut self.underlyingBalances, balance);
  }
}
