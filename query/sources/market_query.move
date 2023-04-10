module protocol_query::market_query {
  
  use std::vector;
  use x::wit_table;
  use x::ac_table;
  use protocol::market::{Self, Market};
  use sui::event::emit;
  use std::fixed_point32::FixedPoint32;
  use std::type_name::TypeName;
  use protocol::borrow_dynamics;
  use protocol::interest_model;
  use protocol::collateral_stats;
  use protocol::reserve;
  use protocol::risk_model;


  struct PoolData has copy, store, drop {
    interestRate: FixedPoint32,
    borrowIndex: u64,
    lastUpdated: u64,
    type: TypeName,
    baseBorrowRatePerSec: FixedPoint32,
    lowSlope: FixedPoint32,
    kink: FixedPoint32,
    highSlope: FixedPoint32,
    reserveFactor: FixedPoint32,
    minBorrowAmount: u64,
    cash: u64,
    debt: u64,
    reserve: u64,
    marketCoinSupply: u64,
  }
  
  struct CollateralData has copy, store, drop {
    type: TypeName,
    collateralFactor: FixedPoint32,
    liquidationFactor: FixedPoint32,
    liquidationPanelty: FixedPoint32,
    liquidationDiscount: FixedPoint32,
    liquidationReserveFactor: FixedPoint32,
    maxCollateralAmount: u64,
    totalCollateralAmount: u64,
  }

  struct MarketData has copy, store, drop {
    pools: vector<PoolData>,
    collaterals: vector<CollateralData>
  }

  public fun market_data(market: &Market) {
    let pools = pool_data(market);
    let collaterals = collateral_data(market);

    emit(MarketData { pools, collaterals });
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
      let borrowDynamic = wit_table::borrow(borrowDynamics, assetType);
      let interestModel = ac_table::borrow(interestModels, assetType);
      let balanceSheet = wit_table::borrow(balanceSheets, assetType);

      let (cash, debt, market, marketCoinSupply) = reserve::balance_sheet(balanceSheet);
      let poolData = PoolData {
        interestRate: borrow_dynamics::interest_rate(borrowDynamic),
        borrowIndex: borrow_dynamics::borrow_index(borrowDynamic),
        lastUpdated: borrow_dynamics::last_updated(borrowDynamic),
        type: interest_model::type_name(interestModel),
        baseBorrowRatePerSec: interest_model::base_borrow_rate(interestModel),
        lowSlope: interest_model::low_slope(interestModel),
        kink: interest_model::kink(interestModel),
        highSlope: interest_model::high_slope(interestModel),
        reserveFactor: interest_model::revenue_factor(interestModel),
        minBorrowAmount: interest_model::min_borrow_amount(interestModel),
        cash,
        debt,
        reserve: market,
        marketCoinSupply
      };
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
      let riskModel = ac_table::borrow(riskModels, collateralType);
      let totalCollateralAmount = collateral_stats::collateral_amount(collateralStats, collateralType);
      let collateralData = CollateralData {
        type: collateralType,
        collateralFactor: risk_model::collateral_factor(riskModel),
        liquidationFactor: risk_model::liq_factor(riskModel),
        liquidationPanelty: risk_model::liq_penalty(riskModel),
        liquidationDiscount: risk_model::liq_discount(riskModel),
        liquidationReserveFactor: risk_model::liq_revenue_factor(riskModel),
        maxCollateralAmount: risk_model::max_collateral_Amount(riskModel),
        totalCollateralAmount,
      };
      vector::push_back(&mut collateralDataList, collateralData);
      i = i + 1;
    };
    collateralDataList
  }
}
