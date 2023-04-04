module protocol_query::obligation_query {
  
  use std::vector;
  use protocol::obligation::{Self, Obligation};
  use protocol::obligation_collaterals::Collateral;
  use protocol::obligation_debts::Debt;
  use x::wit_table;
  
  struct ObligationData has copy {
    collaterals: vector<Collateral>,
    debts: vector<Debt>
  }
  
  public fun obligation_data(obligation: &Obligation): ObligationData {
    let collaterals = collateral_data(obligation);
    let debts = debt_data(obligation);
    ObligationData { collaterals, debts }
  }
  
  public fun collateral_data(obligation: &Obligation): vector<Collateral> {
    let collaterals = obligation::collaterals(obligation);
    let collateralTypes = wit_table::keys(collaterals);
    let (i, n) = (0, vector::length(&collateralTypes));
    let collateralData = vector::empty<Collateral>();
    while(i < n) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let collateral = *wit_table::borrow(collaterals, collateralType);
      vector::push_back(&mut collateralData, collateral);
      i = i + 1;
    };
    collateralData
  }
  
  public fun debt_data(obligation: &Obligation): vector<Debt> {
    let debts = obligation::debts(obligation);
    let debtTypes = wit_table::keys(debts);
    let (i, n) = (0, vector::length(&debtTypes));
    let debtData = vector::empty<Debt>();
    while(i < n) {
      let debtType = *vector::borrow(&debtTypes, i);
      let debt = *wit_table::borrow(debts, debtType);
      vector::push_back(&mut debtData, debt);
      i = i + 1;
    };
    debtData
  }
}
