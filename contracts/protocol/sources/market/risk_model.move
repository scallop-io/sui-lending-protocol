module protocol::risk_model {
use std::type_name::{Self, TypeName};
 use  std::uq32_32::{Self, UQ32_32};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use math::UQ32_32_empower;
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
  const ConstantScale: u64 = 100;

  
  struct RiskModels has drop {}
  
  struct RiskModel has copy, store, drop {
    type: TypeName,
    collateral_factor: UQ32_32,
    liquidation_factor: UQ32_32,
    liquidation_penalty: UQ32_32,
    liquidation_discount: UQ32_32,
    liquidation_revenue_factor: UQ32_32,
    max_collateral_amount: u64
  }

  struct RiskModelChangeCreated has copy, drop {
    risk_model: RiskModel,
    current_epoch: u64, // the epoch when the change is created
    delay_epoches: u64, // the delay epoches before the change takes effect
    effective_epoches: u64, // the epoch when the change takes effect
  }

  struct RiskModelAdded has copy, drop {
    risk_model: RiskModel,
    current_epoch: u64, // the epoch when the change takes effect
  }
  
  public fun collateral_factor(model: &RiskModel): UQ32_32 { model.collateral_factor }
  public fun liq_factor(model: &RiskModel): UQ32_32 { model.liquidation_factor }
  public fun liq_penalty(model: &RiskModel): UQ32_32 { model.liquidation_penalty }
  public fun liq_discount(model: &RiskModel): UQ32_32 { model.liquidation_discount }
  public fun liq_revenue_factor(model: &RiskModel): UQ32_32 { model.liquidation_revenue_factor }
  public fun max_collateral_Amount(model: &RiskModel): u64 { model.max_collateral_amount }
  public fun type_name(model: &RiskModel): TypeName { model.type }
  
  public(friend) fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    AcTableCap<RiskModels>
  )  {
    ac_table::new(RiskModels {}, true, ctx)
  }
  
  public(friend) fun create_risk_model_change<T>(
    _: &AcTableCap<RiskModels>,
    collateral_factor: u64, // exp. 70%,
    liquidation_factor: u64, // exp. 80%,
    liquidation_penalty: u64, // exp. 7%,
    liquidation_discount: u64, // exp. 5%,
    scale: u64,
    max_collateral_amount: u64,
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let collateral_factor = uq32_32::from_quotient(collateral_factor, scale);
    let max_collateral_factor = uq32_32::from_quotient(MaxCollateralFactor, ConstantScale);
    assert!(UQ32_32_empower::gt(collateral_factor, max_collateral_factor) == false, error::risk_model_param_error());

    let liquidation_factor = uq32_32::from_quotient(liquidation_factor, scale);
    let max_liquidation_factor = uq32_32::from_quotient(MaxLiquidationFactor, ConstantScale);
    assert!(UQ32_32_empower::gt(liquidation_factor, max_liquidation_factor) == false, error::risk_model_param_error());

    let liquidation_penalty = uq32_32::from_quotient(liquidation_penalty, scale);
    let max_liquidation_penalty = uq32_32::from_quotient(MaxLiquidationPenalty, ConstantScale);
    assert!(UQ32_32_empower::gt(liquidation_penalty, max_liquidation_penalty) == false, error::risk_model_param_error());

    let liquidation_discount = uq32_32::from_quotient(liquidation_discount, scale);
    let max_liquidation_discount = uq32_32::from_quotient(MaxLiquidationDiscount, ConstantScale);
    assert!(UQ32_32_empower::gt(liquidation_discount, max_liquidation_discount) == false, error::risk_model_param_error());

    // Make sure liquidation factor is bigger than collateral factor
    assert!(UQ32_32_empower::gt(liquidation_factor, collateral_factor), error::risk_model_param_error());
    // Make sure liquidation penalty is bigger than liquidation discount
    assert!(UQ32_32_empower::gte(liquidation_penalty, liquidation_discount), error::risk_model_param_error());
    // Make sure:  liquidation_penalty + liquidation_factor < 1
    let liq_sum = UQ32_32_empower::add(liquidation_factor, liquidation_penalty);
    let liq_sum_max = UQ32_32_empower::from_u64(1);
    assert!(UQ32_32_empower::gt(liq_sum_max, liq_sum), error::risk_model_param_error());

    let liquidation_revenue_factor = UQ32_32_empower::sub(liquidation_penalty, liquidation_discount);
    let risk_model = RiskModel {
      type: type_name::with_defining_ids<T>(),
      collateral_factor,
      liquidation_factor,
      liquidation_penalty,
      liquidation_discount,
      liquidation_revenue_factor,
      max_collateral_amount
    };
    emit(RiskModelChangeCreated {
      risk_model,
      current_epoch: tx_context::epoch(ctx),
      delay_epoches: change_delay,
      effective_epoches: tx_context::epoch(ctx) + change_delay
    });
    one_time_lock_value::new(risk_model, change_delay, RiskModelChangeEffectiveEpoches, ctx)
  }
  
  public(friend) fun add_risk_model<T>(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    risk_model_change: OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext,
  ) {
    let risk_model = one_time_lock_value::get_value(risk_model_change, ctx);
    let type_name = type_name::with_defining_ids<T>();
    assert!(risk_model.type == type_name, error::risk_model_type_not_match_error());

    // Check if the risk model already exists, if so, remove it first
    if (ac_table::contains(self, type_name)) {
      ac_table::remove(self, cap, type_name);
    };

    // Add the new risk model
    ac_table::add(self, cap, type_name, risk_model);

    // Emit the event
    emit(RiskModelAdded {
      risk_model,
      current_epoch: tx_context::epoch(ctx)
    });
  }
}
