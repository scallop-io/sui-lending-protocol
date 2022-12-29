module protocol::risk_model {
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableCap};
  use math::fr::{fr, Fr};
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct RiskModel has store {
    collateralFactor: Fr,
    liquidationFactor: Fr,
    liquidationDiscount: Fr,
    seizeShare: Fr,
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    minimumBorrowAmount: u64,
  }
  
  struct RiskModels has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<RiskModels, TypeName, RiskModel>,
    AcTableCap<RiskModels>
  )  {
    ac_table::new(RiskModels {}, false, ctx)
  }
  
  public fun register_risk_model(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    typeName: TypeName,
    collateralFactorEnu: u64,
    collateralFactorDeno: u64,
    liquidationFactorEnu: u64,
    liquidationFactorDeno: u64,
    liquidationDiscountEnu: u64,
    liquidationDiscountDeno: u64,
    seizeShareEnu: u64,
    seizeShareDeno: u64,
    minimumBorrowAmount: u64,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let riskModel = RiskModel {
      collateralFactor: fr(collateralFactorEnu, collateralFactorDeno),
      liquidationFactor: fr(liquidationFactorEnu, liquidationFactorDeno),
      liquidationDiscount: fr(liquidationDiscountEnu, liquidationDiscountDeno),
      seizeShare: fr(seizeShareEnu, seizeShareDeno),
      minimumBorrowAmount
    };
    ac_table::add(self, cap, typeName, riskModel);
  }
  
  public fun collateral_factor(
    self: &AcTable<RiskModels, TypeName, RiskModel>,
    typeName: TypeName,
  ): Fr {
    let riskModel = ac_table::borrow(self, typeName);
    riskModel.collateralFactor
  }
  
  public fun liquidation_factor(
    self: &AcTable<RiskModels, TypeName, RiskModel>,
    typeName: TypeName,
  ): Fr {
    let riskModel = ac_table::borrow(self, typeName);
    riskModel.liquidationFactor
  }
  
  public fun liquidation_discount(
    self: &AcTable<RiskModels, TypeName, RiskModel>,
    typeName: TypeName,
  ): Fr {
    let riskModel = ac_table::borrow(self, typeName);
    riskModel.liquidationDiscount
  }
}
