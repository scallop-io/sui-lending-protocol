module protocol_query::reserve_query {
  
  use std::vector;
  use x::wit_table;
  use x::ac_table;
  use protocol::reserve::{Self, Reserve};
  use protocol::reserve_vault;
  use protocol::borrow_dynamics::BorrowDynamic;
  use protocol::interest_model::InterestModel;
  use protocol::reserve_vault::BalanceSheet;
  use protocol::risk_model::RiskModel;
  use protocol::collateral_stats::CollateralStat;
  
  struct PoolData has copy {
    borrowDynamic: BorrowDynamic,
    interestModel: InterestModel,
    balanceSheet: BalanceSheet
  }
  
  struct CollateralData has copy {
    riskModel: RiskModel,
    collateralStat: CollateralStat
  }
  
  struct ReserveData has copy {
    pools: vector<PoolData>,
    collaterals: vector<CollateralData>
  }
  
  public fun reserve_data(reserve: &Reserve): ReserveData {
    let pools = pool_data(reserve);
    let collaterals = collateral_data(reserve);
    ReserveData { pools, collaterals }
  }
  
  public fun pool_data(reserve: &Reserve): vector<PoolData> {
    let borrowDynamics = reserve::borrow_dynamics(reserve);
    let interestModels = reserve::interest_models(reserve);
    let vault = reserve::vault(reserve);
    let balanceSheets = reserve_vault::balance_sheets(vault);
    
    let poolAssetTypes = ac_table::keys(interestModels);
    let (i, n) = (0, vector::length(&poolAssetTypes));
    let poolDataList = vector::empty<PoolData>();
    while(i < n) {
      let assetType = *vector::borrow(&poolAssetTypes, i);
      let borrowDynamic = *wit_table::borrow(borrowDynamics, assetType);
      let interestModel = *ac_table::borrow(interestModels, assetType);
      let balanceSheet = *wit_table::borrow(balanceSheets, assetType);
      let poolData = PoolData { borrowDynamic, interestModel, balanceSheet };
      vector::push_back(&mut poolDataList, poolData);
      i = i + 1;
    };
    poolDataList
  }
  
  public fun collateral_data(reserve: &Reserve): vector<CollateralData> {
    let riskModels = reserve::risk_models(reserve);
    let collateralStats = reserve::collateral_stats(reserve);
    let collateralTypes = ac_table::keys(riskModels);
    let (i, n) = (0, vector::length(&collateralTypes));
    let collateralDataList = vector::empty<CollateralData>();
    while (i < n) {
      let collateralType = *vector::borrow(&collateralTypes, i);
      let riskModel = *ac_table::borrow(riskModels, collateralType);
      let collateralStat = *wit_table::borrow(collateralStats, collateralType);
      let collateralData = CollateralData { riskModel, collateralStat };
      vector::push_back(&mut collateralDataList, collateralData);
      i = i + 1;
    };
    collateralDataList
  }
}
