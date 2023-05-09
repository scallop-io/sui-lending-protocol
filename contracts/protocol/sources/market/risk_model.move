module protocol::risk_model {
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use math::fixed_point32_empower;

  // TODO: change it to a bgger value when launch on mainnet
  const RiskModelChangeDelay: u64 = 0;
  
  const ECollateralFactoryTooBig: u64 = 0;
  const ERiskModelTypeNotMatch: u64 = 1;
  
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
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    AcTableCap<RiskModels>
  )  {
    ac_table::new(RiskModels {}, true, ctx)
  }
  
  public fun create_risk_model_change<T>(
    _: &AcTableCap<RiskModels>,
    collateral_factor: u64, // exp. 70%,
    liquidation_factor: u64, // exp. 80%,
    liquidation_penalty: u64, // exp. 7%,
    liquidation_discount: u64, // exp. 95%,
    scale: u64,
    max_collateral_amount: u64,
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
    one_time_lock_value::new(riskModel, RiskModelChangeDelay, 7, ctx)
  }
  
  public fun add_risk_model<T>(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    risk_model_change: OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext,
  ) {
    let risk_model = one_time_lock_value::get_value(risk_model_change, ctx);
    let type_name = get<T>();
    assert!(risk_model.type == type_name, ERiskModelTypeNotMatch);
    ac_table::add(self, cap, get<T>(), risk_model);
  }
}
