module protocol_test::constants {
  use sui::math;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  struct RiskModelParams<phantom T> has copy, drop {
    collateralFactor: u64,
    liquidationFactor: u64,
    liquidationPanelty: u64,
    liquidationDiscount: u64,
    scale: u64,
  }
  
  struct InterestModelParams<phantom T> has copy, drop {
    baseRatePerSec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64,
    reserveFactor: u64,
    scale: u64,
    minBorrowAmount: u64,
  }
  
  public fun collateral_factor<T>(params: &RiskModelParams<T>): u64 { params.collateralFactor }
  public fun liquidation_factor<T>(params: &RiskModelParams<T>): u64 { params.liquidationFactor }
  public fun liquidation_panelty<T>(params: &RiskModelParams<T>): u64 { params.liquidationPanelty }
  public fun liquidation_discount<T>(params: &RiskModelParams<T>): u64 { params.liquidationDiscount }
  public fun risk_model_scale<T>(params: &RiskModelParams<T>): u64 { params.scale }
  
  public fun base_rate_per_sec<T>(params: &InterestModelParams<T>): u64 { params.baseRatePerSec }
  public fun low_slope<T>(params: &InterestModelParams<T>): u64 { params.lowSlope }
  public fun kink<T>(params: &InterestModelParams<T>): u64 { params.kink }
  public fun high_slope<T>(params: &InterestModelParams<T>): u64 { params.highSlope }
  public fun reserve_factor<T>(params: &InterestModelParams<T>): u64 { params.reserveFactor }
  public fun interest_model_scale<T>(params: &InterestModelParams<T>): u64 { params.scale }
  public fun min_borrow_amount<T>(params: &InterestModelParams<T>): u64 { params.minBorrowAmount }
  
  
  public fun eth_risk_model_params(): RiskModelParams<ETH> {
    RiskModelParams {
      collateralFactor: 70,
      liquidationFactor: 80,
      liquidationPanelty: 8,
      liquidationDiscount: 5,
      scale: 100,
    }
  }
  
  public fun usdc_interest_model_params(): InterestModelParams<USDC> {
    InterestModelParams {
      baseRatePerSec: 634195840,
      lowSlope: 20 * math::pow(10, 8),
      kink: 80 * math::pow(10, 16),
      highSlope: 380 * math::pow(10, 8),
      reserveFactor: 2 * math::pow(10, 16),
      scale: math::pow(10, 18),
      minBorrowAmount: math::pow(10, 8),
    }
  }
}
