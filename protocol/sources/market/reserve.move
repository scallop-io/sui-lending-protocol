module protocol::reserve {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use x::supply_bag::{Self, SupplyBag};
  use x::balance_bag::{Self, BalanceBag};
  use x::wit_table::{Self, WitTable};
  use math::u64;
  
  friend protocol::market;
  
  const EFlashLoanNotPaidEnough: u64 = 0;
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has copy, store {
    cash: u64,
    debt: u64,
    revenue: u64,
    marketCoinSupply: u64,
  }
  
  struct FlashLoan<phantom T> {
    amount: u64
  }
  
  struct MarketCoin<phantom T> has drop {}
  
  struct Reserve has key, store {
    id: UID,
    marketCoinSupplies: SupplyBag,
    underlyingBalances: BalanceBag,
    balanceSheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
  }
  
  public fun market_coin_supplies(vault: &Reserve): &SupplyBag { &vault.marketCoinSupplies }
  public fun underlying_balances(vault: &Reserve): &BalanceBag { &vault.underlyingBalances }
  public fun balance_sheets(vault: &Reserve): &WitTable<BalanceSheets, TypeName, BalanceSheet> { &vault.balanceSheets }
  
  public fun balance_sheet(balanceSheet: &BalanceSheet): (u64, u64, u64, u64) {
    (balanceSheet.cash, balanceSheet.debt, balanceSheet.revenue, balanceSheet.marketCoinSupply)
  }
  
  // create a vault for storing underlying assets and market coin supplies
  public(friend) fun new(ctx: &mut TxContext): Reserve {
    Reserve {
      id: object::new(ctx),
      marketCoinSupplies: supply_bag::new(ctx),
      underlyingBalances: balance_bag::new(ctx),
      balanceSheets: wit_table::new(BalanceSheets{}, true, ctx),
    }
  }
  
  public(friend) fun register_coin<T>(self: &mut Reserve) {
    supply_bag::init_supply(MarketCoin<T> {}, &mut self.marketCoinSupplies);
    balance_bag::init_balance<T>(&mut self.underlyingBalances);
    let balanceSheet = BalanceSheet { cash: 0, debt: 0, revenue: 0, marketCoinSupply: 0 };
    wit_table::add(BalanceSheets{}, &mut self.balanceSheets, get<T>(), balanceSheet);
  }
  
  public fun ulti_rate(self: &Reserve, typeName: TypeName): FixedPoint32 {
    let balanceSheet = wit_table::borrow(&self.balanceSheets, typeName);
    if (balanceSheet.debt > 0)  {
      fixed_point32::create_from_rational(balanceSheet.debt, balanceSheet.debt + balanceSheet.cash)
    } else {
      fixed_point32::create_from_rational(0, 1)
    }
  }
  
  public fun asset_types(self: &Reserve): vector<TypeName> {
    wit_table::keys(&self.balanceSheets)
  }
  
  public(friend) fun increase_debt(
    self: &mut Reserve,
    debtType: TypeName,
    debtIncreaseRate: FixedPoint32, // How much debt should be increased in percent, such as 0.05%
    revenueFactor: FixedPoint32,
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, debtType);
    let debtIncreased = fixed_point32::multiply_u64(balanceSheet.debt, debtIncreaseRate);
    let revenueIncreased = fixed_point32::multiply_u64(debtIncreased, revenueFactor);
    balanceSheet.debt = balanceSheet.debt + debtIncreased;
    balanceSheet.revenue = balanceSheet.revenue + revenueIncreased;
  }
  
  public(friend) fun handle_repay<T>(
    self: &mut Reserve,
    balance: Balance<T>
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash + balance::value(&balance);
    balanceSheet.debt = balanceSheet.debt - balance::value(&balance);
    balance_bag::join(&mut self.underlyingBalances, balance)
  }

  public(friend) fun handle_borrow<T>(
    self: &mut Reserve,
    amount: u64
  ): Balance<T> {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash - amount;
    balanceSheet.debt = balanceSheet.debt + amount;
    balance_bag::split<T>(&mut self.underlyingBalances, amount)
  }

  public(friend) fun handle_liquidation<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    revenueBalance: Balance<T>,
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    balanceSheet.cash = balanceSheet.cash + balance::value(&balance);
    balanceSheet.debt = balanceSheet.debt - balance::value(&balance);
    balance_bag::join(&mut self.underlyingBalances, balance);

    balanceSheet.revenue = balanceSheet.revenue + balance::value(&revenueBalance);
    balance_bag::join(&mut self.underlyingBalances, revenueBalance);
  }


  public(friend) fun mint_market_coin<T>(
    self: &mut Reserve,
    underlyingBalance: Balance<T>,
  ): Balance<MarketCoin<T>> {
    let underlyingAmount = balance::value(&underlyingBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let mintAmount = if (balanceSheet.marketCoinSupply > 0) {
      u64::mul_div(underlyingAmount, balanceSheet.marketCoinSupply, balanceSheet.cash + balanceSheet.debt)
    } else {
      underlyingAmount
    };
    balanceSheet.cash = balanceSheet.cash + underlyingAmount;
    balanceSheet.marketCoinSupply = balanceSheet.marketCoinSupply + mintAmount;
    balance_bag::join(&mut self.underlyingBalances, underlyingBalance);
    supply_bag::increase_supply<MarketCoin<T>>(&mut self.marketCoinSupplies, mintAmount)
  }
  
  public(friend) fun redeem_underlying_coin<T>(
    self: &mut Reserve,
    marketCoinBalance: Balance<MarketCoin<T>>,
  ): Balance<T> {
    let marketCoinAmount = balance::value(&marketCoinBalance);
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balanceSheets, get<T>());
    let redeemAmount = u64::mul_div(
      marketCoinAmount, balanceSheet.cash + balanceSheet.debt, balanceSheet.marketCoinSupply
    );
    balanceSheet.cash = balanceSheet.cash - redeemAmount;
    balanceSheet.marketCoinSupply = balanceSheet.marketCoinSupply - marketCoinAmount;
    supply_bag::decrease_supply(&mut self.marketCoinSupplies, marketCoinBalance);
    balance_bag::split<T>(&mut self.underlyingBalances, redeemAmount)
  }
  
  public fun borrow_flash_loan<T>(
    self: &mut Reserve,
    amount: u64
  ): (Balance<T>, FlashLoan<T>) {
    let balance = balance_bag::split<T>(&mut self.underlyingBalances, amount);
    let flashLoan = FlashLoan<T> { amount };
    (balance, flashLoan)
  }
  
  public fun return_flash_loan<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    flashLoan: FlashLoan<T>,
  ) {
    let FlashLoan { amount } = flashLoan;
    assert!(balance::value(&balance) >= amount, EFlashLoanNotPaidEnough);
    balance_bag::join(&mut self.underlyingBalances, balance);
  }
}
