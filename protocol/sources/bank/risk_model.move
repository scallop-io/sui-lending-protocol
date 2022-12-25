module protocol::risk_model {
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use math::exponential::{Self, Exp};
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct RiskModel has store {
    collateralFactor: Exp,
  }
  
  struct RiskModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    Ownership<AcTableOwnership>
  )  {
    ac_table::new(RiskModels {}, false, ctx)
  }
  
  public fun register_collateral_type(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    ownership: &Ownership<AcTableOwnership>,
    typeName: TypeName,
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let riskModel = RiskModel {
      collateralFactor: exponential::exp(collateralFactorEnu, collateralFactorDeno),
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
