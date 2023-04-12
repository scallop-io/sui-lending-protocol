module protocol_test::constants {
  use sui::math;
  use test_coin::eth::ETH;
  use test_coin::btc::BTC;
  use test_coin::usdc::USDC;
  
  struct RiskModelParams<phantom T> has copy, drop {
    collateralFactor: u64,
    liquidationFactor: u64,
    liquidationPenalty: u64,
    liquidationDiscount: u64,
    scale: u64,
    maxCollateralAmount: u64
  }
  
  struct InterestModelParams<phantom T> has copy, drop {
    baseRatePerSec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64,
    revenueFactor: u64,
    scale: u64,
    minBorrowAmount: u64,
    borrow_weight: u64,
  }
  
  public fun collateral_factor<T>(params: &RiskModelParams<T>): u64 { params.collateralFactor }
  public fun liquidation_factor<T>(params: &RiskModelParams<T>): u64 { params.liquidationFactor }
  public fun liquidation_penalty<T>(params: &RiskModelParams<T>): u64 { params.liquidationPenalty }
  public fun liquidation_discount<T>(params: &RiskModelParams<T>): u64 { params.liquidationDiscount }
  public fun risk_model_scale<T>(params: &RiskModelParams<T>): u64 { params.scale }
  public fun max_collateral_amount<T>(params: &RiskModelParams<T>): u64 { params.maxCollateralAmount }
  
  public fun base_rate_per_sec<T>(params: &InterestModelParams<T>): u64 { params.baseRatePerSec }
  public fun low_slope<T>(params: &InterestModelParams<T>): u64 { params.lowSlope }
  public fun kink<T>(params: &InterestModelParams<T>): u64 { params.kink }
  public fun high_slope<T>(params: &InterestModelParams<T>): u64 { params.highSlope }
  public fun revenue_factor<T>(params: &InterestModelParams<T>): u64 { params.revenueFactor }
  public fun interest_model_scale<T>(params: &InterestModelParams<T>): u64 { params.scale }
  public fun min_borrow_amount<T>(params: &InterestModelParams<T>): u64 { params.minBorrowAmount }
  public fun borrow_weight<T>(params: &InterestModelParams<T>): u64 { params.borrow_weight }
  
  public fun eth_risk_model_params(): RiskModelParams<ETH> {
    RiskModelParams {
      collateralFactor: 70,
      liquidationFactor: 80,
      liquidationPenalty: 8,
      liquidationDiscount: 5,
      scale: 100,
      maxCollateralAmount: math::pow(10, 9 + 7)
    }
  }

  public fun btc_risk_model_params(): RiskModelParams<BTC> {
    RiskModelParams {
      collateralFactor: 70,
      liquidationFactor: 80,
      liquidationPenalty: 8,
      liquidationDiscount: 5,
      scale: 100,
      maxCollateralAmount: math::pow(10, 9 + 7)
    }
  }
  
  public fun usdc_interest_model_params(): InterestModelParams<USDC> {
    InterestModelParams {
      baseRatePerSec: 6341958,
      lowSlope: 2 * math::pow(10, 16),
      kink: 80 * math::pow(10, 14),
      highSlope: 20 * math::pow(10, 16),
      revenueFactor: 2 * math::pow(10, 14),
      scale: math::pow(10, 16),
      minBorrowAmount: math::pow(10, 8),
      borrow_weight: math::pow(10, 16),
    }
  }
}
