module protocol::reserve {
  
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use sui::balance::{Self, Balance};
  use sui::object::{Self, UID};
  use sui::coin::{Self, Coin};
  use sui::math;
  use x::supply_bag::{Self, SupplyBag};
  use x::balance_bag::{Self, BalanceBag};
  use x::wit_table::{Self, WitTable};
  use math::u64;
  use sui::dynamic_field;
  use protocol::error;

  friend protocol::market;

  const FlashloanFeeScale: u64 = 10000;

  struct BalanceSheets has drop {}
  
  struct BalanceSheet has copy, store {
    cash: u64,
    debt: u64,
    revenue: u64,
    market_coin_supply: u64,
  }

  struct FlashLoanFees has drop {}
  
  struct FlashLoan<phantom T> {
    loan_amount: u64,
    fee: u64,
  }
  
  struct MarketCoin<phantom T> has drop {}
  
  struct Reserve has key, store {
    id: UID,
    market_coin_supplies: SupplyBag,
    underlying_balances: BalanceBag,
    balance_sheets: WitTable<BalanceSheets, TypeName, BalanceSheet>,
    flash_loan_fees: WitTable<FlashLoanFees, TypeName, u64>,
  }

  struct NonIntrestRevenueKey has copy, store, drop {}

  public fun flash_loan_loan_amount<T>(flash_loan: &FlashLoan<T>): u64 { flash_loan.loan_amount }
  public fun flash_loan_fee<T>(flash_loan: &FlashLoan<T>): u64 { flash_loan.fee }
  
  public fun market_coin_supplies(vault: &Reserve): &SupplyBag { &vault.market_coin_supplies }
  public fun underlying_balances(vault: &Reserve): &BalanceBag { &vault.underlying_balances }
  public fun balance_sheets(vault: &Reserve): &WitTable<BalanceSheets, TypeName, BalanceSheet> { &vault.balance_sheets }
  public fun asset_types(self: &Reserve): vector<TypeName> {
    wit_table::keys(&self.balance_sheets)
  }

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
      flash_loan_fees: wit_table::new(FlashLoanFees{}, true, ctx)
    }
  }
  
  public(friend) fun register_coin<T>(self: &mut Reserve) {
    supply_bag::init_supply(MarketCoin<T> {}, &mut self.market_coin_supplies);
    balance_bag::init_balance<T>(&mut self.underlying_balances);
    let balance_sheet = BalanceSheet { cash: 0, debt: 0, revenue: 0, market_coin_supply: 0 };
    wit_table::add(BalanceSheets{}, &mut self.balance_sheets, get<T>(), balance_sheet);
    wit_table::add(FlashLoanFees{}, &mut self.flash_loan_fees, get<T>(), 0);
  }
  
  public fun util_rate(self: &Reserve, type_name: TypeName): FixedPoint32 {
    let balance_sheet = wit_table::borrow(&self.balance_sheets, type_name);
    if (balance_sheet.debt > 0)  {
      fixed_point32::create_from_rational(
        balance_sheet.debt,
        balance_sheet.debt + balance_sheet.cash - balance_sheet.revenue,
      )
    } else {
      fixed_point32::create_from_rational(0, 1)
    }
  }

  /// This is invoked whenever interest is accrued
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
    let repay_amount = balance::value(&balance);
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    if (balance_sheet.debt >= repay_amount) {
      balance_sheet.debt = balance_sheet.debt - repay_amount;
    } else {
      balance_sheet.revenue = balance_sheet.revenue + (repay_amount - balance_sheet.debt);
      balance_sheet.debt = 0;
    };
    balance_sheet.cash = balance_sheet.cash + repay_amount;
    balance_bag::join(&mut self.underlying_balances, balance)
  }

  public(friend) fun handle_borrow<T>(
    self: &mut Reserve,
    amount: u64
  ): Balance<T> {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    assert!(balance_sheet.cash >= amount, error::reserve_not_enough_error());
    balance_sheet.cash = balance_sheet.cash - amount;
    balance_sheet.debt = balance_sheet.debt + amount;

    // Make sure cash is always bigger than revenue
    assert!(balance_sheet.cash >= balance_sheet.revenue, error::pool_liquidity_not_enough_error());

    balance_bag::split<T>(&mut self.underlying_balances, amount)
  }

  public(friend) fun handle_liquidation<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    revenue_balance: Balance<T>,
  ) {
    // update balance sheet
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    balance_sheet.cash = balance_sheet.cash + balance::value(&balance) + balance::value(&revenue_balance);
    balance_sheet.revenue = balance_sheet.revenue + balance::value(&revenue_balance);
    balance_sheet.debt = balance_sheet.debt - balance::value(&balance);

    // put back the balance
    balance_bag::join(&mut self.underlying_balances, balance);
    balance_bag::join(&mut self.underlying_balances, revenue_balance);
  }

  public(friend) fun mint_market_coin<T>(
    self: &mut Reserve,
    underlying_balance: Balance<T>,
  ): Balance<MarketCoin<T>> {
    // Calculate how much market coin should be minted
    let underlying_amount = balance::value(&underlying_balance);
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    let mint_amount = if (balance_sheet.market_coin_supply > 0) {
      u64::mul_div(
        underlying_amount,
        balance_sheet.market_coin_supply,
        balance_sheet.cash + balance_sheet.debt - balance_sheet.revenue
      )
    } else {
      underlying_amount
    };
    assert!(mint_amount > 0, error::mint_market_coin_too_small_error());

    // Update balance sheet
    balance_sheet.cash = balance_sheet.cash + underlying_amount;
    balance_sheet.market_coin_supply = balance_sheet.market_coin_supply + mint_amount;

    // Mint market coin
    balance_bag::join(&mut self.underlying_balances, underlying_balance);
    supply_bag::increase_supply<MarketCoin<T>>(&mut self.market_coin_supplies, mint_amount)
  }
  
  public(friend) fun redeem_underlying_coin<T>(
    self: &mut Reserve,
    market_coin_balance: Balance<MarketCoin<T>>,
  ): Balance<T> {
    // Calculate how much underlying coin should be redeemed
    let market_coin_amount = balance::value(&market_coin_balance);
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    let redeem_amount = u64::mul_div(
      market_coin_amount,
      balance_sheet.cash + balance_sheet.debt - balance_sheet.revenue,
      balance_sheet.market_coin_supply
    );

    assert!(redeem_amount > 0, error::redeem_market_coin_too_small_error());
    assert!(balance_sheet.cash >= redeem_amount, error::reserve_not_enough_error());

    // Update balance sheet
    balance_sheet.cash = balance_sheet.cash - redeem_amount;
    balance_sheet.market_coin_supply = balance_sheet.market_coin_supply - market_coin_amount;

    // Make sure cash is always bigger than revenue
    assert!(balance_sheet.cash >= balance_sheet.revenue, error::pool_liquidity_not_enough_error());

    // Redeem underlying coin
    supply_bag::decrease_supply(&mut self.market_coin_supplies, market_coin_balance);
    balance_bag::split<T>(&mut self.underlying_balances, redeem_amount)
  }

  public(friend) fun set_flash_loan_fee<T>(
    self: &mut Reserve,
    fee: u64, // 0 - 10000
  ) {
    let current_fee = wit_table::borrow_mut(FlashLoanFees{}, &mut self.flash_loan_fees, get<T>());
    *current_fee = fee;
  }
  
  public(friend) fun borrow_flash_loan<T>(
    self: &mut Reserve,
    amount: u64,
    ctx: &mut TxContext,
  ): (Coin<T>, FlashLoan<T>) {
    let (loan, receipt) = borrow_flash_loan_internal(self, amount, 0, 1); // fee discount is none
    (coin::from_balance(loan, ctx), receipt)
  }

  fun borrow_flash_loan_internal<T>(
    self: &mut Reserve,
    amount: u64,
    fee_discount_numerator: u64,
    fee_discount_denominator: u64,
  ): (Balance<T>, FlashLoan<T>) {
    let balance = balance_bag::split<T>(&mut self.underlying_balances, amount);
    let fee_rate = *wit_table::borrow(&self.flash_loan_fees, get<T>());
    let base_fee = if (fee_rate > 0) {
      // charge at least 1 unit of coin when fee_rate is not 0
      amount * fee_rate / FlashloanFeeScale + 1
    } else {
      0
    };
    let fee_discount = if (fee_discount_numerator > 0 && fee_discount_denominator > 0) {
      u64::mul_div(base_fee, fee_discount_numerator, fee_discount_denominator)
    } else {
      0
    };
    let fee = base_fee - fee_discount;
    let flash_loan = FlashLoan<T> { loan_amount: amount, fee };
    (balance, flash_loan)
  }

  public(friend) fun repay_flash_loan<T>(
    self: &mut Reserve,
    coin: Coin<T>,
    flash_loan: FlashLoan<T>,
  ) {
    let FlashLoan { loan_amount, fee } = flash_loan;
    let repaid_amount = coin::value(&coin);
    assert!(repaid_amount >= loan_amount + fee, error::flash_loan_repay_not_enough_error());

    // update balance sheet
    let collected_fee = repaid_amount - loan_amount;
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    balance_sheet.cash = balance_sheet.cash + collected_fee;
    balance_sheet.revenue = balance_sheet.revenue + collected_fee;

    // repay flash loan
    balance_bag::join(&mut self.underlying_balances, coin::into_balance(coin));
  }

  /// Take revenue of the protocol from the reserve
  public(friend) fun take_revenue<T>(
    self: &mut Reserve,
    amount: u64,
    ctx: &mut TxContext,
  ): Coin<T> {
    let balance_sheet = wit_table::borrow_mut(BalanceSheets{}, &mut self.balance_sheets, get<T>());
    let all_revenue = balance_sheet.revenue;
    let take_amount = math::min(amount, all_revenue);

    // update balance sheet
    balance_sheet.revenue = balance_sheet.revenue - take_amount;
    balance_sheet.cash = balance_sheet.cash - take_amount;

    // take revenue
    let balance = balance_bag::split<T>(&mut self.underlying_balances, take_amount);
    coin::from_balance(balance, ctx)
  }

  /// Add non-intrest revenue to the reserve, such as borrowing fee
  public(friend) fun add_non_intrest_revenue<T>(
    self: &mut Reserve,
    balance: Balance<T>,
    ctx: &mut TxContext,
  ) {
    // Check if the balance bag exists for the revenue
    let key = NonIntrestRevenueKey{};
    let has_record = dynamic_field::exists_with_type<NonIntrestRevenueKey, BalanceBag>(&self.id, key);
    // If not exists, create a new one
    if (!has_record) {
      dynamic_field::add(&mut self.id, key, balance_bag::new(ctx));
    };

    // Retrieve the balance bag
    let balances = dynamic_field::borrow_mut<NonIntrestRevenueKey, BalanceBag>(&mut self.id, key);
    // Create a balance record if not exists
    if (!balance_bag::contains<T>(balances)) {
      balance_bag::init_balance<T>(balances);
    };
    // Add the revenue to the balance
    balance_bag::join<T>(balances, balance);
  }

  /// Take non-intrest revenue from the reserve
  /// Dev: since this function is meant for admin only, we don't do the checks of existence
  public(friend) fun take_non_intrest_revenue<T>(
    self: &mut Reserve,
    amount: u64,
    ctx: &mut TxContext,
  ): Coin<T> {
    // Retrieve the balance bag
    let key = NonIntrestRevenueKey{};
    let balances = dynamic_field::borrow_mut<NonIntrestRevenueKey, BalanceBag>(&mut self.id, key);
    // Take the revenue from the balance
    let balance = balance_bag::split<T>(balances, amount);
    coin::from_balance(balance, ctx)
  }
}
