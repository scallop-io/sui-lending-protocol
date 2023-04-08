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
  
  struct RiskModel has copy, store {
    type: TypeName,
    collateralFactor: FixedPoint32,
    liquidationFactor: FixedPoint32,
    liquidationPenalty: FixedPoint32,
    liquidationDiscount: FixedPoint32,
    liquidationRevenueFactor: FixedPoint32,
    maxCollateralAmount: u64
  }
  
  public fun collateral_factor(model: &RiskModel): FixedPoint32 { model.collateralFactor }
  public fun liq_factor(model: &RiskModel): FixedPoint32 { model.liquidationFactor }
  public fun liq_penalty(model: &RiskModel): FixedPoint32 { model.liquidationPenalty }
  public fun liq_discount(model: &RiskModel): FixedPoint32 { model.liquidationDiscount }
  public fun liq_revenue_factor(model: &RiskModel): FixedPoint32 { model.liquidationRevenueFactor }
  public fun max_collateral_Amount(model: &RiskModel): u64 { model.maxCollateralAmount }
  public fun type_name(model: &RiskModel): TypeName { model.type }
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    AcTableCap<RiskModels>
  )  {
    ac_table::new(RiskModels {}, true, ctx)
  }
  
  public fun create_risk_model_change<T>(
    _: &AcTableCap<RiskModels>,
    collateralFactor: u64, // exp. 70%,
    liquidationFactor: u64, // exp. 80%,
    liquidationPenalty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
    maxCollateralAmount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let liquidationPenalty = fixed_point32::create_from_rational(liquidationPenalty, scale);
    let liquidationDiscount = fixed_point32::create_from_rational(liquidationDiscount, scale);
    let liquidationRevenueFactor = fixed_point32_empower::sub(liquidationPenalty, liquidationDiscount);
    let collateralFactor = fixed_point32::create_from_rational(collateralFactor, scale);
    let liquidationFactor = fixed_point32::create_from_rational(liquidationFactor, scale);
    let riskModel = RiskModel {
      type: get<T>(),
      collateralFactor,
      liquidationFactor,
      liquidationPenalty,
      liquidationDiscount,
      liquidationRevenueFactor,
      maxCollateralAmount
    };
    one_time_lock_value::new(riskModel, RiskModelChangeDelay, 7, ctx)
  }
  
  public fun add_risk_model<T>(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    riskModelChange: &mut OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext,
  ) {
    let riskModel = one_time_lock_value::get_value(riskModelChange, ctx);
    let typeName = get<T>();
    assert!(riskModel.type == typeName, ERiskModelTypeNotMatch);
    ac_table::add(self, cap, get<T>(), riskModel);
  }
}
