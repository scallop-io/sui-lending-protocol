module mobius_protocol::bank_state {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};
  use math::exponential::{Self, Exp, exp};
  use x::ac_table::AcTable;
  use mobius_protocol::interest_model::{InterestModels, InterestModel};
  use mobius_protocol::interest_model;
  
  struct BankState has store {
    cash: u128,
    debt: u128,
    reserve: u128,
    mark: Exp,
    interestRate: Exp,
    lastUpdated: u64,
  }
  
  struct BankStates has drop {}
  
  public fun new(ctx: &mut TxContext): WitTable<BankStates, TypeName, BankState> {
    wit_table::new<BankStates, TypeName, BankState>(
      BankStates{},
      false,
      ctx
    )
  }
  
  /// return (totalLending, totalCash, totalReserve)
  public fun borrow_mark(
    self: &WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName
  ): Exp {
    let stat = wit_table::borrow(self, typeName);
    stat.mark
  }
  
  public fun handle_repay(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    stat.debt = stat.debt - (repayAmount as u128);
    stat.cash = stat.cash + (repayAmount as u128);
  }
  
  public fun accrue_interest(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
    now: u64,
  ) {
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    /*********
    timeDelta = now - lastUpdated
    *********/
    let timeDelta = ((now - stat.lastUpdated) as u128);
    
    /*********
    increaseFactor = 1 + timeDelta * interestRate
    *********/
    let increaseFactor = exponential::add_exp(
      exp(1, 1),
      exponential::mul_scalar_exp(stat.interestRate, timeDelta)
    );
    
    /*********
    newDebt = oldDebt * increaseFactor
    *********/
    let oldDebt =stat.debt;
    stat.debt = exponential::mul_scalar_exp_truncate(
      stat.debt,
      increaseFactor
    );
    
    /*********
    newMark = oldMark * increaseFactor
    *********/
    stat.mark = exponential::mul_exp(stat.mark, increaseFactor);
    
    /*******
     newReserve = reserve + reserveFactor * (newDebt - oldDebt)
    ********/
    let reserveFactor = interest_model::reserve_factor(interestModels, typeName);
    stat.reserve = stat.reserve + exponential::mul_scalar_exp_truncate(
      (stat.debt - oldDebt),
      reserveFactor
    );
    
    // set lastUpdated to now
    stat.lastUpdated = now
  }
  
  public fun update_interest_rate(
    self: &mut WitTable<BankStates, TypeName, BankState>,
    interestModels: &AcTable<InterestModels, TypeName, InterestModel>,
    typeName: TypeName,
  ) {
    /*******
    update interest with the new bank ulti rate
    ultiRate = debt / (debt + cash - reserve)
    ********/
    let stat = wit_table::borrow_mut(BankStates{}, self, typeName);
    let ultiRate = exponential::exp(stat.debt, stat.debt + stat.cash - stat.reserve);
    let interestRate = interest_model::calc_interest(interestModels, typeName, ultiRate);
    stat.interestRate = interestRate;
  }
}
