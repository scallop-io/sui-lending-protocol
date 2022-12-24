module mobius_protocol::collateral_config {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use math::exponential::{Self, Exp};
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct CollateralConfig has store {
    reserveFactor: Exp,
    disbled: bool
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
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
  ) {
    assert!(collateralFactorEnu < collateralFactorDeno, ECollateralFactoryTooBig);
    let config = CollateralConfig {
      reserveFactor: exponential::exp(collateralFactorEnu, collateralFactorDeno),
      disbled: false
    };
    ac_table::add(self, ownership, typeName, config);
  }
  
  public fun collateral_factor(
    self: &AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    typeName: TypeName
  ): Exp {
    let config = ac_table::borrow(self, typeName);
    config.reserveFactor
  }
}
