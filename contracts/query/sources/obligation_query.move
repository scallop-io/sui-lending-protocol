module protocol_query::obligation_query {
  
  use std::vector;
  use sui::clock::Clock;
  use std::type_name::TypeName;
  use sui::event::emit;
  use x::wit_table;
  use protocol::obligation::{Self, Obligation};
  use protocol::obligation_collaterals;
  use protocol::obligation_debts;
  use protocol::version::Version;
  use protocol::market::Market;

  struct CollateralData has copy, store, drop {
    type: TypeName,
    amount: u64
  }

  struct DebtData has copy, store, drop {
    type: TypeName,
    amount: u64,
    borrowIndex: u64,
  }

  struct ObligationData has copy, store, drop {
    collaterals: vector<CollateralData>,
    debts: vector<DebtData>
  }

  public fun obligation_data(version: &Version, market: &mut Market, obligation: &mut Obligation, clock: &Clock) {
    protocol::accrue_interest::accrue_interest_for_market_and_obligation(version, market, obligation, clock);

    let collaterals = collateral_data(obligation);
    let debts = debt_data(obligation);
    let obligationData =  ObligationData { collaterals, debts };
    emit(obligationData);
  }
  
  public fun collateral_data(obligation: &Obligation): vector<CollateralData> {
    let collaterals = obligation::collaterals(obligation);
    let collateralTypes = wit_table::keys(collaterals);
    let (i, n) = (0, vector::length(&collateralTypes));
    let collateralDataVec= vector::empty<CollateralData>();
    while(i < n) {
      let type = *vector::borrow(&collateralTypes, i);
      let amount = obligation_collaterals::collateral(collaterals, type);
      vector::push_back(&mut collateralDataVec, CollateralData { type, amount } );
      i = i + 1;
    };
    collateralDataVec
  }
  
  public fun debt_data(obligation: &Obligation): vector<DebtData> {
    let debts = obligation::debts(obligation);
    let debtTypes = wit_table::keys(debts);
    let (i, n) = (0, vector::length(&debtTypes));
    let debtDataVec = vector::empty<DebtData>();
    while(i < n) {
      let type = *vector::borrow(&debtTypes, i);
      let (amount, borrowIndex) = obligation_debts::debt(debts, type);
      vector::push_back(&mut debtDataVec, DebtData { type, amount, borrowIndex });
      i = i + 1;
    };
    debtDataVec
  }
}
