module protocol::risk_model {
  use std::type_name::{TypeName, get};
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use math::fr::{fr, Fr};
  use math::fr;
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct RiskModels has drop {}
  
  struct RiskModel has store {
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
  
  public fun register_risk_model<T>(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    collateralFactor: u64, // exp. 70%,
    liquidationFactor: u64, // exp. 80%,
    liquidationPanelty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
  ) {
    assert!(collateralFactor < scale, ECollateralFactoryTooBig);
    let liquidationPanelty = fr(liquidationPanelty, scale);
    let liquidationDiscount = fr(liquidationDiscount, scale);
    let liquidationReserveFactor = fr::div(
      fr::sub(liquidationPanelty, liquidationDiscount),
      liquidationDiscount
    );
    let riskModel = RiskModel {
      collateralFactor: fr(collateralFactor, scale),
      liquidationFactor: fr(liquidationFactor, scale),
      liquidationPanelty,
      liquidationDiscount,
      liquidationReserveFactor,
    };
    ac_table::add(self, cap, get<T>(), riskModel);
  }
}
