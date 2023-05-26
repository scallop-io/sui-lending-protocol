module protocol::risk_model {
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use protocol::error;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use math::fixed_point32_empower;

  friend protocol::app;
  friend protocol::market;

  const RiskModelChangeEffectiveEpoches: u64 = 7;
  
  struct RiskModels has drop {}
  
  struct RiskModel has copy, store, drop {
    type: TypeName,
    collateral_factor: FixedPoint32,
    liquidation_factor: FixedPoint32,
    liquidation_penalty: FixedPoint32,
    liquidation_discount: FixedPoint32,
    liquidation_revenue_factor: FixedPoint32,
    max_collateral_amount: u64
  }
  
  public fun collateral_factor(model: &RiskModel): FixedPoint32 { model.collateral_factor }
  public fun liq_factor(model: &RiskModel): FixedPoint32 { model.liquidation_factor }
  public fun liq_penalty(model: &RiskModel): FixedPoint32 { model.liquidation_penalty }
  public fun liq_discount(model: &RiskModel): FixedPoint32 { model.liquidation_discount }
  public fun liq_revenue_factor(model: &RiskModel): FixedPoint32 { model.liquidation_revenue_factor }
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
    let liquidation_penalty = fixed_point32::create_from_rational(liquidation_penalty, scale);
    let liquidation_discount = fixed_point32::create_from_rational(liquidation_discount, scale);
    let liquidation_revenue_factor = fixed_point32_empower::sub(liquidation_penalty, liquidation_discount);
    let collateral_factor = fixed_point32::create_from_rational(collateral_factor, scale);
    let liquidation_factor = fixed_point32::create_from_rational(liquidation_factor, scale);
    let riskModel = RiskModel {
      type: get<T>(),
      collateral_factor,
      liquidation_factor,
      liquidation_penalty,
      liquidation_discount,
      liquidation_revenue_factor,
      max_collateral_amount
    };
    one_time_lock_value::new(riskModel, change_delay, RiskModelChangeEffectiveEpoches, ctx)
  }
  
  public(friend) fun add_risk_model<T>(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    risk_model_change: OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext,
  ) {
    let risk_model = one_time_lock_value::get_value(risk_model_change, ctx);
    let type_name = get<T>();
    assert!(risk_model.type == type_name, error::risk_model_type_not_match_error());

    // Check if the risk model already exists, if so, remove it first
    if (ac_table::contains(self, type_name)) {
      ac_table::remove(self, cap, type_name);
    };

    // Add the new risk model
    ac_table::add(self, cap, get<T>(), risk_model);
  }
}
