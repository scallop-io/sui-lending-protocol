module protocol::risk_model {
  use std::type_name::TypeName;
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
    /********
    when the principal and ratio of borrow indices are both small,
    the result can equal the principal, due to automatic truncation of division
    newDebt = debt * (current borrow index) / (original borrow index)
    so that the user could borrow without interest
    *********/
    minBorrowAmount: u64,
  }
  
  public fun collateral_factor(model: &RiskModel): Fr { model.collateralFactor }
  public fun min_borrow_amount(model: &RiskModel): u64 { model.minBorrowAmount }
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
  
  public fun register_risk_model(
    self: &mut AcTable<RiskModels, TypeName, RiskModel>,
    cap: &AcTableCap<RiskModels>,
    typeName: TypeName,
    collateralFactorEnu: u64, // exp. 70%,
    collateralFactorDeno: u64,
    liquidationFactorEnu: u64, // exp. 80%,
    liquidationFactorDeno: u64,
    liquidationPaneltyEnu: u64, // exp. 7%,
    liquidationPaneltyDeno: u64,
    liquidationDiscountEnu: u64, // exp. 95%,
    liquidationDiscountDeno: u64,
    minBorrowAmount: u64,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let liquidationPanelty = fr(liquidationPaneltyEnu, liquidationPaneltyDeno);
    let liquidationDiscount = fr(liquidationDiscountEnu, liquidationDiscountDeno);
    let liquidationReserveFactor = fr::div(
      fr::sub(liquidationPanelty, liquidationDiscount),
      liquidationDiscount
    );
    let riskModel = RiskModel {
      collateralFactor: fr(collateralFactorEnu, collateralFactorDeno),
      liquidationFactor: fr(liquidationFactorEnu, liquidationFactorDeno),
      liquidationPanelty,
      liquidationDiscount,
      liquidationReserveFactor,
      minBorrowAmount
    };
    ac_table::add(self, cap, typeName, riskModel);
  }
}
