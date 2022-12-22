module mobius_core::collateral_config {
  
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::tx_context;
  use math::exponential::Exp;
  use x::ac_table;
  use x::ac_table::{AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use sui::object::UID;
  use sui::object;
  use std::type_name;
  use math::exponential;
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct COLLATERAL_CONFIG has drop {}
  
  struct ConfigData has store {
    collateralFactor: Exp,
  }
  
  struct CollateralConfig has key {
    id: UID,
    acTable: AcTable<COLLATERAL_CONFIG, TypeName, ConfigData>
  }
  
  struct CollateralConfigOwnership has key, store {
    id: UID,
    ownership: Ownership<AcTableOwnership>
  }
  
  fun init(witness: COLLATERAL_CONFIG, ctx: &mut TxContext) {
    let (acTable, acTableCap) = ac_table::new<COLLATERAL_CONFIG, TypeName, ConfigData>(
      witness,
      true,
      ctx
    );
    transfer::share_object(
      CollateralConfig {
        id: object::new(ctx),
        acTable
      }
    );
    transfer::transfer(
      CollateralConfigOwnership {
        id: object::new(ctx),
        ownership: acTableCap,
      },
      tx_context::sender(ctx)
    )
  }
  
  public entry fun register_collateral_type<T>(
    self: &mut CollateralConfig,
    ownership: &CollateralConfigOwnership,
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
  ) {
    let config = ConfigData {
      collateralFactor: exponential::exp(collateralFactorEnu, collateralFactorDeno)
    };
    let typeName = type_name::get<T>();
    ac_table::add(
      &mut self.acTable,
      &ownership.ownership,
      typeName,
      config
    );
  }
  
  /// Return the stored collateral factor, or 0 if none
  public fun collateral_factor(
    self: &CollateralConfig,
    typeName: TypeName,
  ): Exp {
    let hasFactor = ac_table::contains(&self.acTable, typeName);
    if (hasFactor) {
      let config = ac_table::borrow(&self.acTable, typeName);
      let factor = config.collateralFactor;
      assert!(exponential::truncate(factor) == 0, ECollateralFactoryTooBig);
      factor
    } else {
      exponential::exp(0u128, 1u128)
    }
  }
}
