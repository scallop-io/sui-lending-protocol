module protocol_query::market_query {
  
  use std::vector;
  use x::wit_table;
  use x::ac_table;
  use protocol::market::{Self, Market};
  use protocol::reserve;
  use protocol::borrow_dynamics::BorrowDynamic;
  use protocol::interest_model::InterestModel;
  use protocol::reserve::BalanceSheet;
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
  
  struct MarketData has copy {
    pools: vector<PoolData>,
    collaterals: vector<CollateralData>
  }
  
  public fun market_data(market: &Market): MarketData {
    let pools = pool_data(market);
    let collaterals = collateral_data(market);
    MarketData { pools, collaterals }
  }
  
  public fun pool_data(market: &Market): vector<PoolData> {
    let borrowDynamics = market::borrow_dynamics(market);
    let interestModels = market::interest_models(market);
    let vault = market::vault(market);
    let balanceSheets = reserve::balance_sheets(vault);
    
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
  
  public fun collateral_data(market: &Market): vector<CollateralData> {
    let riskModels = market::risk_models(market);
    let collateralStats = market::collateral_stats(market);
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
