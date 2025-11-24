module protocol::hashi_risk_model {
  use std::type_name::{TypeName, get};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use decimal::decimal::{Self, Decimal};

  use protocol::error;

  friend protocol::app;
  friend protocol::market;

  const RiskModelChangeEffectiveEpoches: u64 = 7;

  /// The maximum values for the risk model parameters
  /// The values are in percentage, e.g. 70 means 70%
  const MaxCollateralFactor: u64 = 95; // 95%
  const MaxLiquidationFactor: u64 = 95; // 95%
  const MaxLiquidationPenalty: u64 = 20; // 20%
  const MaxLiquidationDiscount: u64 = 15; // 15%

  
  struct RiskModels has drop {}
  
  struct HashiRiskModel has copy, store, drop {
    collateral_factor: Decimal,
    liquidation_factor: Decimal,
    liquidation_penalty: Decimal,
    liquidation_discount: Decimal,
    liquidation_revenue_factor: Decimal,
    max_collateral_amount: u64
  }

  struct HashiRiskModelChangeCreated has copy, drop {
    hashi_risk_model: HashiRiskModel,
    current_epoch: u64, // the epoch when the change is created
    delay_epoches: u64, // the delay epoches before the change takes effect
    effective_epoches: u64, // the epoch when the change takes effect
  }

  struct RiskModelAdded has copy, drop {
    risk_model: HashiRiskModel,
    current_epoch: u64, // the epoch when the change takes effect
  }
  
  public fun collateral_factor(model: &HashiRiskModel): Decimal { model.collateral_factor }
  public fun liq_factor(model: &HashiRiskModel): Decimal { model.liquidation_factor }
  public fun liq_penalty(model: &HashiRiskModel): Decimal { model.liquidation_penalty }
  public fun liq_discount(model: &HashiRiskModel): Decimal { model.liquidation_discount }
  public fun liq_revenue_factor(model: &HashiRiskModel): Decimal { model.liquidation_revenue_factor }
  public fun max_collateral_Amount(model: &HashiRiskModel): u64 { model.max_collateral_amount }

  public(friend) fun new(ctx: &mut TxContext): (
  )  {
    ac_table::new(RiskModels {}, true, ctx)
  }
  
  public(friend) fun create_hashi_risk_model_change(
    collateral_factor_percent: u64, // exp. 70%,
    liquidation_factor_percent: u64, // exp. 80%,
    liquidation_penalty_percent: u64, // exp. 7%,
    liquidation_discount_percent: u64, // exp. 5%,
    max_collateral_amount: u64,
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<HashiRiskModel> {
    let collateral_factor = decimal::from_percent_u64(collateral_factor_percent);
    let max_collateral_factor = decimal::from_percent_u64(MaxCollateralFactor);
    assert!(decimal::le(collateral_factor, max_collateral_factor), error::risk_model_param_error());


    let liquidation_factor = decimal::from_percent_u64(liquidation_factor_percent);
    let max_liquidation_factor = decimal::from_percent_u64(MaxLiquidationFactor);
    assert!(decimal::le(liquidation_factor, max_liquidation_factor), error::risk_model_param_error());

    let liquidation_penalty = decimal::from_percent_u64(liquidation_penalty_percent);
    let max_liquidation_penalty = decimal::from_percent_u64(MaxLiquidationPenalty);
    assert!(decimal::le(liquidation_penalty, max_liquidation_penalty), error::risk_model_param_error());

    let liquidation_discount = decimal::from_percent_u64(liquidation_discount_percent);
    let max_liquidation_discount = decimal::from_percent_u64(MaxLiquidationDiscount);
    assert!(decimal::le(liquidation_discount, max_liquidation_discount), error::risk_model_param_error());

    // Make sure liquidation factor is bigger than collateral factor
    assert!(decimal::gt(liquidation_factor, collateral_factor), error::risk_model_param_error());
    // Make sure liquidation penalty is bigger than liquidation discount
    assert!(decimal::ge(liquidation_penalty, liquidation_discount), error::risk_model_param_error());

    let liquidation_revenue_factor = decimal::sub(liquidation_penalty, liquidation_discount);
    let hashi_risk_model = HashiRiskModel {
      collateral_factor,
      liquidation_factor,
      liquidation_penalty,
      liquidation_discount,
      liquidation_revenue_factor,
      max_collateral_amount
    };
    emit(HashiRiskModelChangeCreated {
      hashi_risk_model,
      current_epoch: tx_context::epoch(ctx),
      delay_epoches: change_delay,
      effective_epoches: tx_context::epoch(ctx) + change_delay
    });
    one_time_lock_value::new(hashi_risk_model, change_delay, RiskModelChangeEffectiveEpoches, ctx)
  }
}
