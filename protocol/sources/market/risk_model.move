module protocol::risk_model {
  use std::type_name::{TypeName, get};
  use std::fixed_point32::{Self, FixedPoint32};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use math::fixed_point32_empower;
  
  const RiskModelChangeDelay: u64 = 7;
  
  const ECollateralFactoryTooBig: u64 = 0;
  const ERiskModelTypeNotMatch: u64 = 1;
  
  struct RiskModels has drop {}
  
  struct RiskModel has copy, store {
    type: TypeName,
    collateralFactor: FixedPoint32,
    liquidationFactor: FixedPoint32,
    liquidationPanelty: FixedPoint32,
    liquidationDiscount: FixedPoint32,
    liquidationMarketFactor: FixedPoint32,
    maxCollateralAmount: u64
  }
  
  public fun collateral_factor(model: &RiskModel): FixedPoint32 { model.collateralFactor }
  public fun liq_factor(model: &RiskModel): FixedPoint32 { model.liquidationFactor }
  public fun liq_panelty(model: &RiskModel): FixedPoint32 { model.liquidationPanelty }
  public fun liq_discount(model: &RiskModel): FixedPoint32 { model.liquidationDiscount }
  public fun liq_market_factor(model: &RiskModel): FixedPoint32 { model.liquidationMarketFactor }
  public fun max_collateral_Amount(model: &RiskModel): u64 { model.maxCollateralAmount }
  
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
    liquidationPanelty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
    maxCollateralAmount: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let liquidationPanelty = fixed_point32::create_from_rational(liquidationPanelty, scale);
    let liquidationDiscount = fixed_point32::create_from_rational(liquidationDiscount, scale);
    let liquidationMarketFactor = fixed_point32_empower::div(
      fixed_point32_empower::sub(liquidationPanelty, liquidationDiscount),
      liquidationDiscount
    );
    let collateralFactor = fixed_point32::create_from_rational(collateralFactor, scale);
    let liquidationFactor = fixed_point32::create_from_rational(liquidationFactor, scale);
    let riskModel = RiskModel {
      type: get<T>(),
      collateralFactor,
      liquidationFactor,
      liquidationPanelty,
      liquidationDiscount,
      liquidationMarketFactor,
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
