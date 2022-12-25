module protocol::risk_model {
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use math::exponential::{Exp, exp};
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct RiskModel has store {
    collateralFactor: Exp,
    // TODO: study how closeFactor works, and implement it
    closeFactor: Exp,
    // TODO: study liquidation mechanism, and implement it
    liquidationIncentive: Exp,
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
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
    closeFactorEnu: u128,
    closeFactorDeno: u128,
    liquidationIncentiveEnu: u128,
    liquidationIncentiveDeno: u128,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let riskModel = RiskModel {
      collateralFactor: exp(collateralFactorEnu, collateralFactorDeno),
      closeFactor: exp(closeFactorEnu, closeFactorDeno),
      liquidationIncentive: exp(liquidationIncentiveEnu, liquidationIncentiveDeno)
    };
    ac_table::add(self, ownership, typeName, riskModel);
  }
  
  public fun collateral_factor(
    self: &AcTable<RiskModels, TypeName, RiskModel>,
    typeName: TypeName,
  ): Exp {
    let riskModel = ac_table::borrow(self, typeName);
    riskModel.collateralFactor
  }
}
