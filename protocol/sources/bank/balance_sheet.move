module protocol::balance_sheet {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::WitTable;
  use x::wit_table;
  use math::fr::{Self, Fr};
  
  friend protocol::bank;
  
  struct BalanceSheets has drop {}
  
  struct BalanceSheet has store {
    cash: u64,
    debt: u64,
    reserve: u64,
    bankCoinSupply: u64,
  }
  
  public(friend) fun new(ctx: &mut TxContext): WitTable<BalanceSheets, TypeName, BalanceSheet> {
    wit_table::new<BalanceSheets, TypeName, BalanceSheet>(BalanceSheets{}, false, ctx)
  }
  
  // update bank balance sheet for repay
  public(friend) fun borrow_mut(
    balanceSheets: &mut WitTable<BalanceSheets, TypeName, BalanceSheet>,
    typeName: TypeName,
  ): &mut BalanceSheet {
    wit_table::borrow_mut(BalanceSheets{}, balanceSheets, typeName)
  }
  
  public fun bank_coin_mint_rate(balanceSheet: &BalanceSheet): Fr {
    fr::fr(
      balanceSheet.bankCoinSupply,
      balanceSheet.cash + balanceSheet.debt,
    )
  }
  
  public fun bank_coin_redeem_rate(balanceSheet: &BalanceSheet): Fr {
    fr::fr(
      balanceSheet.cash + balanceSheet.debt,
      balanceSheet.bankCoinSupply,
    )
  }
  
  // update bank balance sheet for repay
  public(friend) fun update_for_repay(
    balanceSheets: &mut WitTable<BalanceSheets, TypeName, BalanceSheet>,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt - repayAmount;
    balanceSheet.cash = balanceSheet.cash + repayAmount;
  }
  
  // update bank balance sheet for borrow
  public(friend) fun update_for_borrow(
    balanceSheets: &mut WitTable<BalanceSheets, TypeName, BalanceSheet>,
    typeName: TypeName,
    borrowAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt + borrowAmount;
    balanceSheet.cash = balanceSheet.cash - borrowAmount;
  }
  
  // update bank balance sheet for liquidation
  public(friend) fun update_for_liquidation(
    balanceSheets: &mut WitTable<BalanceSheets, TypeName, BalanceSheet>,
    typeName: TypeName,
    repayAmount: u64,
    reserveAmount: u64
  ) {
    let balanceSheet = wit_table::borrow_mut(BalanceSheets{}, balanceSheets, typeName);
    balanceSheet.debt = balanceSheet.debt - repayAmount;
    balanceSheet.cash = balanceSheet.cash + repayAmount;
    balanceSheet.reserve = balanceSheet.reserve + reserveAmount;
  }
  
  public fun ulti_rate(
    balanceSheets: &WitTable<BalanceSheets, TypeName, BalanceSheet>,
    typeName: TypeName,
  ): Fr {
    let balanceSheet = wit_table::borrow(balanceSheets, typeName);
    fr::fr(
      balanceSheet.debt,
      balanceSheet.debt + balanceSheet.cash
    )
  }
}
