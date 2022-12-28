module protocol::risk_model {
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use math::fr::{fr, Fr};
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct RiskModel has store {
    collateralFactor: Fr,
    // TODO: study how closeFactor works, and implement it
    closeFactor: Fr,
    // TODO: study liquidation mechanism, and implement it
    liquidationIncentive: Fr,
  }
  
  struct RiskModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    Ownership<AcTableOwnership>
  )  {
    ac_table::new(RiskModels {}, false, ctx)
  }
  
  public fun register_risk_model(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    ownership: &Ownership<AcTableOwnership>,
    typeName: TypeName,
    collateralFactorEnu: u64,
    collateralFactorDeno: u64,
    closeFactorEnu: u64,
    closeFactorDeno: u64,
    liquidationIncentiveEnu: u64,
    liquidationIncentiveDeno: u64,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let riskModel = RiskModel {
      collateralFactor: fr(collateralFactorEnu, collateralFactorDeno),
      closeFactor: fr(closeFactorEnu, closeFactorDeno),
      liquidationIncentive: fr(liquidationIncentiveEnu, liquidationIncentiveDeno)
    };
    ac_table::add(self, ownership, typeName, riskModel);
  }
  
  public fun collateral_factor(
    self: &AcTable<RiskModels, TypeName, RiskModel>,
    typeName: TypeName,
  ): Fr {
    let riskModel = ac_table::borrow(self, typeName);
    riskModel.collateralFactor
  }
}
