module mobius_protocol::protocol_dynamics {
  
  use std::type_name::TypeName;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self ,UID};
  use sui::transfer;
  use x::wit_table::WitTable;
  use x::ac_table::{AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use mobius_protocol::bank_state::{Self, BankStates, BankState};
  use mobius_protocol::collateral_config::{Self, CollateralConfigs, CollateralConfig};
  use mobius_protocol::interest_model::{Self, InterestModel, InterestModels};
  use mobius_protocol::borrow_mark::{Self, BorrowMarks, BorrowMark};
  use math::exponential;
  use math::exponential::Exp;
  use x::ac_table;
  
  struct ProtocolDynamics has key {
    id: UID,
    collateralConfigs: AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    bankStates: WitTable<BankStates, TypeName, BankState>,
    borrowMarks: WitTable<BorrowMarks, TypeName, BorrowMark>,
  }
  
  struct ProtocolDynamicsCap has key, store {
    id: UID,
    collateralConfigsOwnership: Ownership<AcTableOwnership>,
    interestModelsOwnership: Ownership<AcTableOwnership>,
  }
  
  fun init(ctx: &mut TxContext) {
    let (collateralConfigs, collateralConfigsOwnership) = collateral_config::new(ctx);
    let (interestModels, interestModelsOwnership) = interest_model::new(ctx);
    let bankStates = bank_state::new(ctx);
    let borrowMarks = borrow_mark::new(ctx);
    let protocolDynamics = ProtocolDynamics {
      id: object::new(ctx),
      collateralConfigs,
      interestModels,
      bankStates,
      borrowMarks
    };
    let protocolDynamicsCap = ProtocolDynamicsCap {
      id: object::new(ctx),
      collateralConfigsOwnership,
      interestModelsOwnership
    };
    transfer::share_object(protocolDynamics);
    transfer::transfer(protocolDynamicsCap, tx_context::sender(ctx));
  }
  
  public fun get_borrow_mark(
    protocolDynamics: &ProtocolDynamics,
    typeName: TypeName,
  ): Exp {
    borrow_mark::get_borrow_mark(&protocolDynamics.borrowMarks, typeName)
  }
  
  public fun inccrue_interest(
    protocolDynamics: &mut ProtocolDynamics,
    typeName: TypeName,
    now: u64,
  ) {
    // store old borrow mark
    let prevBorrowMark = borrow_mark::get_borrow_mark(&protocolDynamics.borrowMarks, typeName);
    // refresh borrow mark and get it
    let curBorrowMark = borrow_mark::refresh_borrow_mark(&mut protocolDynamics.borrowMarks, typeName, now);
    // get the previous bank state
    let (debt, cash, reserve) = bank_state::get_bank_state(&protocolDynamics.bankStates, typeName);
    // calc new debt, using the borrow mark
    let newDebt = exponential::mul_scalar_exp_truncate(
      (debt as u128),
      exponential::div_exp(curBorrowMark, prevBorrowMark)
    );
    
    // Reserve accure
    let reserveFactor = interest_model::reserve_factor(&protocolDynamics.interestModels, typeName);
    let reserveDelta = exponential::mul_scalar_exp_truncate(
      (newDebt - (debt as u128)),
      reserveFactor
    );
    let newReserve = reserve + (reserveDelta as u64);
    // store the new debt
    bank_state::update_bank_state(
      &mut protocolDynamics.bankStates,
      typeName, (newDebt as u64), cash, newReserve
    );
  }
  
  // Always update interest rate after each operation
  public fun update_interest_rate(
    protocolDynamics: &mut ProtocolDynamics,
    typeName: TypeName,
  ) {
    // get the latest ulti rate
    let (debt, cash, reserve) = bank_state::get_bank_state(&protocolDynamics.bankStates, typeName);
    let ultiRate = exponential::exp(
      (debt as u128),
      ((debt + cash - reserve) as u128)
    );
    // calc the interest with interest model and ulti rate
    let interestRate = interest_model::calc_interest(&protocolDynamics.interestModels, typeName, ultiRate);
    // store the new interest rate
    borrow_mark::update_interest_rate(&mut protocolDynamics.borrowMarks, typeName, interestRate);
  }
  
  public fun handle_repay(
    protocolDynamics: &mut ProtocolDynamics,
    typeName: TypeName,
    repayAmount: u64
  ) {
    let bankStates = &mut protocolDynamics.bankStates;
    let (debt, cash, reserve) = bank_state::get_bank_state(bankStates, typeName);
    let debt =  debt - repayAmount;
    let cash = cash + repayAmount;
    bank_state::update_bank_state(bankStates, typeName, debt, cash, reserve);
  }
  
  public fun update_bank_state(
    protocolDynamics: &mut ProtocolDynamics,
    typeName: TypeName,
    debt: u64,
    cash: u64,
    reserve: u64,
  ) {
    bank_state::update_bank_state(
      &mut protocolDynamics.bankStates,
      typeName, debt, cash, reserve
    );
  }
  
  public fun collateral_factor(
    protocolDynamics: &ProtocolDynamics,
    typeName: TypeName,
  ): Exp {
    let config = ac_table::borrow(&protocolDynamics.collateralConfigs, typeName);
    let (enu, deno) = collateral_config::collateral_factor(config);
    exponential::exp((enu as u128), (deno as u128))
  }
}
