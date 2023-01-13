module protocol::risk_model {
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use math::fr::{Self, Fr};
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use sui::tx_context;
  
  const RiskModelChangeDelay: u64 = 0;
  
  const ECollateralFactoryTooBig: u64 = 0;
  const ERiskModelTypeNotMatch: u64 = 1;
  
  struct RiskModels has drop {}
  
  struct RiskModel has copy, store {
    type: TypeName,
    collateralFactor: Fr,
    liquidationFactor: Fr,
    liquidationPanelty: Fr,
    liquidationDiscount: Fr,
    liquidationReserveFactor: Fr,
  }
  
  public fun collateral_factor(model: &RiskModel): Fr { model.collateralFactor }
  public fun liq_factor(model: &RiskModel): Fr { model.liquidationFactor }
  public fun liq_panelty(model: &RiskModel): Fr { model.liquidationPanelty }
  public fun liq_discount(model: &RiskModel): Fr { model.liquidationDiscount }
  public fun liq_reserve_factor(model: &RiskModel): Fr { model.liquidationReserveFactor }
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    AcTableCap<RiskModels>
  )  {
    ac_table::new(RiskModels {}, false, ctx)
  }
  
  public fun create_risk_model_change<T>(
    _: &AcTableCap<RiskModels>,
    collateralFactor: u64, // exp. 70%,
    liquidationFactor: u64, // exp. 80%,
    liquidationPanelty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<RiskModel> {
    let liquidationPanelty = fr::fr(liquidationPanelty, scale);
    let liquidationDiscount = fr::fr(liquidationDiscount, scale);
    let liquidationReserveFactor = fr::div(
      fr::sub(liquidationPanelty, liquidationDiscount),
      liquidationDiscount
    );
    let riskModel = RiskModel {
      type: get<T>(),
      collateralFactor: fr::fr(collateralFactor, scale),
      liquidationFactor: fr::fr(liquidationFactor, scale),
      liquidationPanelty,
      liquidationDiscount,
      liquidationReserveFactor,
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
