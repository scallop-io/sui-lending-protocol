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
    market_coin_supply: u64,
  }
  
  struct FlashLoan<phantom T> {
    amount: u64
  }
  
  struct MarketCoin<phantom T> has drop {}
  
  struct Reserve has key, store {
    id: UID,
    market_coin_supplies: SupplyBag,
    underlying_balances: BalanceBag,
    balance_sheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
  }
  
  public fun market_coin_supplies(vault: &Reserve): &SupplyBag { &vault.market_coin_supplies }
  public fun underlying_balances(vault: &Reserve): &BalanceBag { &vault.underlying_balances }
  public fun balance_sheets(vault: &Reserve): &WitTable<BalanceSheets, TypeName, BalanceSheet> { &vault.balance_sheets }
  
  public fun balance_sheet(balance_sheet: &BalanceSheet): (u64, u64, u64, u64) {
    (balance_sheet.cash, balance_sheet.debt, balance_sheet.revenue, balance_sheet.market_coin_supply)
  }
  
  // create a vault for storing underlying assets and market coin supplies
  public(friend) fun new(ctx: &mut TxContext): Reserve {
    Reserve {
      id: object::new(ctx),
      market_coin_supplies: supply_bag::new(ctx),
      underlying_balances: balance_bag::new(ctx),
      balance_sheets: wit_table::new(BalanceSheets{}, true, ctx),
    }
  }
  
  public(friend) fun register_coin<T>(self: &mut Reserve) {
    supply_bag::init_supply(MarketCoin<T> {}, &mut self.market_coin_supplies);
    balance_bag::init_balance<T>(&mut self.underlying_balances);
    let balance_sheet = BalanceSheet { cash: 0, debt: 0, revenue: 0, market_coin_supply: 0 };
    wit_table::add(BalanceSheets{}, &mut self.balance_sheets, get<T>(), balance_sheet);
  }
  
  public fun ulti_rate(self: &Reserve, type_name: TypeName): FixedPoint32 {
    let balance_sheet = wit_table::borrow(&self.balance_sheets, type_name);
    if (balance_sheet.debt > 0)  {
      fixed_point32::create_from_rational(balance_sheet.debt, balance_sheet.debt + balance_sheet.cash)
    } else {
      fixed_point32::create_from_rational(0, 1)
    }
  }
  
  public fun asset_types(self: &Reserve): vector<TypeName> {
    wit_table::keys(&self.balance_sheets)
  }
  
  public(friend) fun increase_debt(
    self: &mut Reserve,
    debt_type: TypeName,
    debt_increase_rate: FixedPoint32, // How much debt should be increased in percent, such as 0.05%
    revenue_factor: FixedPoint32,
  ) {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, debt_type);
    let debt_increased = fixed_point32::multiply_u64(balance_sheet.debt, debt_increase_rate);
    let revenue_increased = fixed_point32::multiply_u64(debt_increased, revenue_factor);
    balance_sheet.debt = balance_sheet.debt + debt_increased;
    balance_sheet.revenue = balance_sheet.revenue + revenue_increased;
  }
  
  public(friend) fun handle_repay<T>(
    self: &mut Reserve,
    balance: Balance<T>
  ) {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    balance_sheet.cash = balance_sheet.cash + balance::value(&balance);
    balance_sheet.debt = balance_sheet.debt - balance::value(&balance);
    balance_bag::join(&mut self.underlying_balances, balance)
  }

  public(friend) fun handle_borrow<T>(
    self: &mut Reserve,
    amount: u64
  ): Balance<T> {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    balance_sheet.cash = balance_sheet.cash - amount;
    balance_sheet.debt = balance_sheet.debt + amount;
    balance_bag::split<T>(&mut self.underlying_balances, amount)
  }

  public(friend) fun handle_liquidation<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    revenue_balance: Balance<T>,
  ) {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    balance_sheet.cash = balance_sheet.cash + balance::value(&balance);
    balance_sheet.debt = balance_sheet.debt - balance::value(&balance);
    balance_bag::join(&mut self.underlying_balances, balance);

    balance_sheet.revenue = balance_sheet.revenue + balance::value(&revenue_balance);
    balance_bag::join(&mut self.underlying_balances, revenue_balance);
  }


  public(friend) fun mint_market_coin<T>(
    self: &mut Reserve,
    underlying_balance: Balance<T>,
  ): Balance<MarketCoin<T>> {
    let underlying_amount = balance::value(&underlying_balance);
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    let mint_amount = if (balance_sheet.market_coin_supply > 0) {
      u64::mul_div(underlying_amount, balance_sheet.market_coin_supply, balance_sheet.cash + balance_sheet.debt)
    } else {
      underlying_amount
    };
    balance_sheet.cash = balance_sheet.cash + underlying_amount;
    balance_sheet.market_coin_supply = balance_sheet.market_coin_supply + mint_amount;
    balance_bag::join(&mut self.underlying_balances, underlying_balance);
    supply_bag::increase_supply<MarketCoin<T>>(&mut self.market_coin_supplies, mint_amount)
  }
  
  public(friend) fun redeem_underlying_coin<T>(
    self: &mut Reserve,
    market_coin_balance: Balance<MarketCoin<T>>,
  ): Balance<T> {
    let market_coin_amount = balance::value(&market_coin_balance);
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    let redeem_amount = u64::mul_div(
      market_coin_amount, balance_sheet.cash + balance_sheet.debt, balance_sheet.market_coin_supply
    );
    balance_sheet.cash = balance_sheet.cash - redeem_amount;
    balance_sheet.market_coin_supply = balance_sheet.market_coin_supply - market_coin_amount;
    supply_bag::decrease_supply(&mut self.market_coin_supplies, market_coin_balance);
    balance_bag::split<T>(&mut self.underlying_balances, redeem_amount)
  }
  
  public(friend) fun borrow_flash_loan<T>(
    self: &mut Reserve,
    amount: u64
  ): (Balance<T>, FlashLoan<T>) {
    let balance = balance_bag::split<T>(&mut self.underlying_balances, amount);
    let flashLoan = FlashLoan<T> { amount };
    (balance, flashLoan)
  }

  // TODO: charge fee for flash loan
  public(friend) fun return_flash_loan<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    flash_loan: FlashLoan<T>,
  ) {
    let FlashLoan { amount } = flash_loan;
    assert!(balance::value(&balance) >= amount, EFlashLoanNotPaidEnough);
    balance_bag::join(&mut self.underlying_balances, balance);
  }
}
