#[test_only]
module protocol::constants {
  use math::u64;
  use test_coin::eth::ETH;
  use test_coin::btc::BTC;
  use test_coin::usdc::USDC;
  use test_coin::usdt::USDT;  
  
  struct RiskModelParams<phantom T> has copy, drop {
    collateral_factor: u64,
    liquidation_factor: u64,
    liquidation_penalty: u64,
    liquidation_discount: u64,
    scale: u64,
    max_collateral_amount: u64
  }
  
  struct InterestModelParams<phantom T> has copy, drop {
    base_rate_per_sec: u64,
    interest_rate_scale: u64,
    borrow_rate_on_mid_kink: u64,
    mid_kink: u64,
    borrow_rate_on_high_kink: u64,
    high_kink: u64,
    max_borrow_rate: u64,
    revenue_factor: u64,
    scale: u64,
    min_borrow_amount: u64,
    borrow_weight: u64,
  }
  
  public fun collateral_factor<T>(params: &RiskModelParams<T>): u64 { params.collateral_factor }
  public fun liquidation_factor<T>(params: &RiskModelParams<T>): u64 { params.liquidation_factor }
  public fun liquidation_penalty<T>(params: &RiskModelParams<T>): u64 { params.liquidation_penalty }
  public fun liquidation_discount<T>(params: &RiskModelParams<T>): u64 { params.liquidation_discount }
  public fun risk_model_scale<T>(params: &RiskModelParams<T>): u64 { params.scale }
  public fun max_collateral_amount<T>(params: &RiskModelParams<T>): u64 { params.max_collateral_amount }
  
  public fun base_rate_per_sec<T>(params: &InterestModelParams<T>): u64 { params.base_rate_per_sec }
  public fun interest_rate_scale<T>(params: &InterestModelParams<T>): u64 { params.interest_rate_scale }
  public fun borrow_rate_on_mid_kink<T>(params: &InterestModelParams<T>): u64 { params.borrow_rate_on_mid_kink }
  public fun mid_kink<T>(params: &InterestModelParams<T>): u64 { params.mid_kink }
  public fun borrow_rate_on_high_kink<T>(params: &InterestModelParams<T>): u64 { params.borrow_rate_on_high_kink }
  public fun high_kink<T>(params: &InterestModelParams<T>): u64 { params.high_kink }
  public fun max_borrow_rate<T>(params: &InterestModelParams<T>): u64 { params.max_borrow_rate }
  public fun revenue_factor<T>(params: &InterestModelParams<T>): u64 { params.revenue_factor }
  public fun interest_model_scale<T>(params: &InterestModelParams<T>): u64 { params.scale }
  public fun min_borrow_amount<T>(params: &InterestModelParams<T>): u64 { params.min_borrow_amount }
  public fun borrow_weight<T>(params: &InterestModelParams<T>): u64 { params.borrow_weight }
  
  public fun set_borrow_weight<T>(params: &mut InterestModelParams<T>, borrow_weight: u64) { params.borrow_weight = borrow_weight; }

  public fun eth_risk_model_params(): RiskModelParams<ETH> {
    RiskModelParams {
      collateral_factor: 70,
      liquidation_factor: 80,
      liquidation_penalty: 8,
      liquidation_discount: 5,
      scale: 100,
      max_collateral_amount: std::u64::pow(10, 9 + 7)
    }
  }

  public fun btc_risk_model_params(): RiskModelParams<BTC> {
    RiskModelParams {
      collateral_factor: 70,
      liquidation_factor: 80,
      liquidation_penalty: 8,
      liquidation_discount: 5,
      scale: 100,
      max_collateral_amount: std::u64::pow(10, 9 + 7)
    }
  }

  public fun usdc_risk_model_params(): RiskModelParams<USDC> {
    RiskModelParams {
      collateral_factor: 80,
      liquidation_factor: 90,
      liquidation_penalty: 8,
      liquidation_discount: 5,
      scale: 100,
      max_collateral_amount: std::u64::pow(10, 9 + 7)
    }
  }
  
  public fun usdc_interest_model_params(): InterestModelParams<USDC> {
    let interest_rate_scale = std::u64::pow(10, 7);
    let scale = std::u64::pow(10, 12);
    let secs_per_year = 365 * 24 * 60 * 60;

    let borrow_rate_on_mid_kink = 8 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let borrow_rate_on_high_kink = 50 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let max_borrow_rate = 300 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    InterestModelParams {
      base_rate_per_sec: 0,
      interest_rate_scale,
      borrow_rate_on_mid_kink,
      borrow_rate_on_high_kink,
      max_borrow_rate,
      mid_kink: u64::mul_div(60, scale, 100),
      high_kink: u64::mul_div(90, scale, 100),
      revenue_factor: u64::mul_div(2, scale, 100),
      scale,
      min_borrow_amount: std::u64::pow(10, 8),
      borrow_weight: 1 * scale,
    }
  }

  public fun usdt_interest_model_params(): InterestModelParams<USDT> {
    let interest_rate_scale = std::u64::pow(10, 7);
    let scale = std::u64::pow(10, 12);
    let secs_per_year = 365 * 24 * 60 * 60;

    let borrow_rate_on_mid_kink = 8 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let borrow_rate_on_high_kink = 50 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let max_borrow_rate = 100 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    InterestModelParams {
      base_rate_per_sec: 0,
      interest_rate_scale,
      borrow_rate_on_mid_kink,
      borrow_rate_on_high_kink,
      max_borrow_rate,
      mid_kink: u64::mul_div(60, scale, 100),
      high_kink: u64::mul_div(90, scale, 100),
      revenue_factor: u64::mul_div(2, scale, 100),
      scale,
      min_borrow_amount: std::u64::pow(10, 8),
      borrow_weight: 1 * scale,
    }
  }  

  public fun eth_interest_model_params(): InterestModelParams<ETH> {
    let interest_rate_scale = std::u64::pow(10, 7);
    let scale = std::u64::pow(10, 12);
    let secs_per_year = 365 * 24 * 60 * 60;

    let borrow_rate_on_mid_kink = 8 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let borrow_rate_on_high_kink = 50 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    let max_borrow_rate = 300 * u64::mul_div(scale, interest_rate_scale, secs_per_year) / 100;
    InterestModelParams {
      base_rate_per_sec: 0,
      interest_rate_scale,
      borrow_rate_on_mid_kink,
      borrow_rate_on_high_kink,
      max_borrow_rate,
      mid_kink: u64::mul_div(60, scale, 100),
      high_kink: u64::mul_div(90, scale, 100),
      revenue_factor: u64::mul_div(2, scale, 100),
      scale,
      min_borrow_amount: std::u64::pow(10, 5),
      borrow_weight: 1 * scale,
    }
  }
}
