module protocol_query::bank_query {
  
  use std::vector;
  use x::wit_table;
  use x::ac_table;
  use protocol::bank::{Self, Bank};
  use protocol::bank_vault;
  use protocol::borrow_dynamics::BorrowDynamic;
  use protocol::interest_model::InterestModel;
  use protocol::bank_vault::BalanceSheet;
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
  
  struct BankData has copy {
    pools: vector<PoolData>,
    collaterals: vector<CollateralData>
  }
  
  public fun bank_data(bank: &Bank): BankData {
    let pools = pool_data(bank);
    let collaterals = collateral_data(bank);
    BankData { pools, collaterals }
  }
  
  public fun pool_data(bank: &Bank): vector<PoolData> {
    let borrowDynamics = bank::borrow_dynamics(bank);
    let interestModels = bank::interest_models(bank);
    let vault = bank::vault(bank);
    let balanceSheets = bank_vault::balance_sheets(vault);
    
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
  
  public fun collateral_data(bank: &Bank): vector<CollateralData> {
    let riskModels = bank::risk_models(bank);
    let collateralStats = bank::collateral_stats(bank);
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
