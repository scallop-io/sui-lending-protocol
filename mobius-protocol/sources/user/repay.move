module mobius_protocol::repay {
  
  use std::vector;
  use std::type_name::{Self, TypeName};
  use sui::coin::{Self, Coin};
  use time::timestamp::{Self ,TimeStamp};
  use mobius_protocol::position::{Self, Position};
  use mobius_protocol::bank::{Self, Bank};
  use mobius_protocol::protocol_dynamics::{Self, ProtocolDynamics};
  use math::exponential;
  
  public entry fun repay<T>(
    position: &mut Position,
    bank: &mut Bank<T>,
    protocolDynamics: &mut ProtocolDynamics,
    timeOracle: &TimeStamp,
    coin: Coin<T>,
  ) {
    // Get all debt types for position
    let repayAmount = coin::value(&coin);
    let debtTypes = position::debt_types(position);
    let now = timestamp::timestamp(timeOracle);
    accrue_interest(protocolDynamics, debtTypes, now);
    // Update the bank balance sheet according to repay amount
    // It must be done before updating interest rate,
    // As it'll impact the ultilization rate
    let typeName = type_name::get<T>();
    protocol_dynamics::handle_repay(protocolDynamics, typeName, repayAmount);
    // Update the interest rate for banks
    update_interest_rate(protocolDynamics, debtTypes);
    // put coin into the bank
    bank::deposit_underlying_coin(bank, coin::into_balance(coin));
    
    
    // accrue interest for postion debts
    accrue_interest_for_position(position, protocolDynamics);
    // remove debt according to repay amount
    position::decrease_debt(position, typeName, repayAmount);
  }
  
  fun accrue_interest(
    protocolDynamics: &mut ProtocolDynamics,
    debtTypes: vector<TypeName>,
    now: u64,
  ) {
    // Inccrue interest for all related banks
    let (i, n) = (0, vector::length(&debtTypes));
    while (i < n) {
      let type = *vector::borrow(&debtTypes, i);
      protocol_dynamics::inccrue_interest(protocolDynamics, type, now);
      i = i + 1;
    };
  }
  
  fun update_interest_rate(
    protocolDynamics: &mut ProtocolDynamics,
    debtTypes: vector<TypeName>,
  ) {
    // Update the interest rate for banks
    let (i, n) = (0, vector::length(&debtTypes));
    while (i < n) {
      let type = *vector::borrow(&debtTypes, i);
      protocol_dynamics::update_interest_rate(protocolDynamics, type);
      i = i + 1;
    };
  }
  
  fun accrue_interest_for_position(
    position: &mut Position,
    protocolDynamics: &ProtocolDynamics,
  ) {
    let debtTypes = position::debt_types(position);
    let (i, n) = (0, vector::length(&debtTypes));
    while (i < n) {
      let type = *vector::borrow(&debtTypes, i);
      let (debtAmount, mark) = position::debt(position, type);
      let currMark = protocol_dynamics::get_borrow_mark(protocolDynamics, type);
      let newDebtAmount = exponential::mul_scalar_exp_truncate(
        (debtAmount as u128),
        exponential::div_exp(currMark, mark)
      );
      position::update_debt(position, type, (newDebtAmount as u64), currMark);
      i = i + 1;
    };
  }
}
