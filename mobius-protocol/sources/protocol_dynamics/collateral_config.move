module mobius_protocol::collateral_config {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct CollateralConfig has store {
    collateralFactorEnu: u64,
    collateralFactorDeno: u64,
  }
  
  struct CollateralConfigs has drop {}
  
  public fun new(ctx: &mut TxContext): (
    AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    Ownership<AcTableOwnership>
  )  {
    ac_table::new<CollateralConfigs, TypeName, CollateralConfig>(
      CollateralConfigs {},
      true,
      ctx
    )
  }
  
  public fun register_collateral_type(
    self: &mut AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    ownership: &Ownership<AcTableOwnership>,
    typeName: TypeName,
    collateralFactorEnu: u64,
    collateralFactorDeno: u64,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let config = CollateralConfig {
      collateralFactorEnu,
      collateralFactorDeno
    };
    ac_table::add(self, ownership, typeName, config);
  }
  
  public fun collateral_factor(configData: &CollateralConfig): (u64, u64) {
    (configData.collateralFactorEnu, configData.collateralFactorDeno)
  }
}
