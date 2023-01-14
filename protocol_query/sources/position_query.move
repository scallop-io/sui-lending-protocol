module protocol_query::position_query {
  
  use std::vector;
  use protocol::position::{Self, Position};
  use protocol::position_collaterals::Collateral;
  use protocol::position_debts::Debt;
  use x::wit_table;
  
  struct PositionData has copy {
    collaterals: vector<Collateral>,
    debts: vector<Debt>
  }
  
  public fun position_data(position: &Position): PositionData {
    let collaterals = collateral_data(position);
    let debts = debt_data(position);
    PositionData { collaterals, debts }
  }
  
  public fun collateral_data(position: &Position): vector<Collateral> {
    let collaterals = position::collaterals(position);
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
  
  public fun debt_data(position: &Position): vector<Debt> {
    let debts = position::debts(position);
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
