module protocol::reserve_vault {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use x::supply_bag::{Self, SupplyBag};
  use x::balance_bag::{Self, BalanceBag};
  use x::wit_table::{Self, WitTable};
  use math::u64;
  
  friend protocol::reserve;
  
  const EFlashLoanNotPaidEnough: u64 = 0;
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has copy, store {
    cash: u64,
    debt: u64,
    reserve: u64,
    reserveCoinSupply: u64,
  }
  
  struct FlashLoan<phantom T> {
    amount: u64
  }
  
  struct ReserveCoin<phantom T> has drop {}
  
  struct ReserveVault has key, store {
    id: UID,
    reserveCoinSupplies: SupplyBag,
    underlyingBalances: BalanceBag,
    balanceSheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
  }
  
  public fun reserve_coin_supplies(vault: &ReserveVault): &SupplyBag { &vault.reserveCoinSupplies }
  public fun underlying_balances(vault: &ReserveVault): &BalanceBag { &vault.underlyingBalances }
  public fun balance_sheets(vault: &ReserveVault): &WitTable<BalanceSheets, TypeName, BalanceSheet> { &vault.balanceSheets }
  
  public fun balance_sheet(balanceSheet: &BalanceSheet): (u64, u64, u64, u64) {
    (balanceSheet.cash, balanceSheet.debt, balanceSheet.reserve, balanceSheet.reserveCoinSupply)
  }
  
  // create a vault for storing underlying assets and reserve coin supplies
  public(friend) fun new(ctx: &mut TxContext): ReserveVault {
    ReserveVault {
      id: object::new(ctx),
      reserveCoinSupplies: supply_bag::new(ctx),
      underlyingBalances: balance_bag::new(ctx),
      balanceSheets: wit_table::new(BalanceSheets{}, true, ctx),
    }
  }
  
  public(friend) fun register_coin<T>(self: &mut ReserveVault) {
    supply_bag::init_supply(ReserveCoin<T> {}, &mut self.reserveCoinSupplies);
    balance_bag::init_balance<T>(&mut self.underlyingBalances);
    let balanceSheet = BalanceSheet { cash: 0, debt: 0, reserve: 0, reserveCoinSupply: 0 };
    wit_table::add(BalanceSheets{}, &mut self.balanceSheets, get<T>(), balanceSheet);
  }
  
  public fun ulti_rate(self: &ReserveVault, typeName: TypeName): FixedPoint32 {
    let balanceSheet = wit_table::borrow(&self.balanceSheets, typeName);
    if (balanceSheet.debt > 0)  {
      fixed_point32::create_from_rational(balanceSheet.debt, balanceSheet.debt + balanceSheet.cash)
    } else {
      fixed_point32::create_from_rational(0, 1)
    }
  }
  
  public fun asset_types(self: &ReserveVault): vector<TypeName> {
    wit_table::keys(&self.balanceSheets)
  }
  
  public(friend) fun increase_debt(
    self: &mut ReserveVault,
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
    self: &mut ReserveVault,
    balance: Balance<T>
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash + balance::value(&balance);
    balance_bag::join(&mut self.underlyingBalances, balance)
  }
  
  public(friend) fun withdraw_underlying_coin<T>(
    self: &mut ReserveVault,
    amount: u64
  ): Balance<T> {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash - amount;
    balance_bag::split<T>(&mut self.underlyingBalances, amount)
  }
  
  public(friend) fun mint_reserve_coin<T>(
    self: &mut ReserveVault,
    underlyingBalance: Balance<T>,
  ): Balance<ReserveCoin<T>> {
    let underlyingAmount = balance::value(&underlyingBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let mintAmount = if (balanceSheet.reserveCoinSupply > 0) {
      u64::mul_div(underlyingAmount, balanceSheet.reserveCoinSupply, balanceSheet.cash + balanceSheet.debt)
    } else {
      underlyingAmount
    };
    balanceSheet.cash = balanceSheet.cash + underlyingAmount;
    balanceSheet.reserveCoinSupply = balanceSheet.reserveCoinSupply + mintAmount;
    balance_bag::join(&mut self.underlyingBalances, underlyingBalance);
    supply_bag::increase_supply<ReserveCoin<T>>(&mut self.reserveCoinSupplies, mintAmount)
  }
  
  public(friend) fun redeem_underlying_coin<T>(
    self: &mut ReserveVault,
    reserveCoinBalance: Balance<ReserveCoin<T>>,
  ): Balance<T> {
    let reserveCoinAmount = balance::value(&reserveCoinBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let redeemAmount = u64::mul_div(
      reserveCoinAmount, balanceSheet.cash + balanceSheet.debt, balanceSheet.reserveCoinSupply
    );
    balanceSheet.cash = balanceSheet.cash - redeemAmount;
    balanceSheet.reserveCoinSupply = balanceSheet.reserveCoinSupply - reserveCoinAmount;
    supply_bag::decrease_supply(&mut self.reserveCoinSupplies, reserveCoinBalance);
    balance_bag::split<T>(&mut self.underlyingBalances, redeemAmount)
  }
  
  public fun borrow_flash_loan<T>(
    self: &mut ReserveVault,
    amount: u64
  ): (Balance<T>, FlashLoan<T>) {
    let balance = balance_bag::split<T>(&mut self.underlyingBalances, amount);
    let flashLoan = FlashLoan<T> { amount };
    (balance, flashLoan)
  }
  
  public fun return_flash_loan<T>(
    self: &mut ReserveVault,
    balance: Balance<T>,
    flashLoan: FlashLoan<T>,
  ) {
    let FlashLoan { amount } = flashLoan;
    assert!(balance::value(&balance) >= amount, EFlashLoanNotPaidEnough);
    balance_bag::join(&mut self.underlyingBalances, balance);
  }
}
