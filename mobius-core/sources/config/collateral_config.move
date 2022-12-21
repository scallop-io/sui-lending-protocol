module mobius_core::collateral_config {
  
  use sui::object::UID;
  use std::type_name::{TypeName, get};
  use sui::table::Table;
  
  use math::exponential::{Self, Exp};
  use std::vector;
  use sui::table;
  use sui::tx_context::TxContext;
  use sui::object;
  use sui::transfer;
  
  friend mobius_core::admin;
  
  const ECollateralFactoryTooBig: u64 = 0;
  
  struct CollateralConfig has key {
    id: UID,
    collateralTypes: vector<TypeName>,
    collateralFactorTable: Table<TypeName, Exp>,
  }
  
  fun init(ctx: &mut TxContext) {
    let config = CollateralConfig {
      id: object::new(ctx),
      collateralTypes: vector::empty(),
      collateralFactorTable: table::new(ctx),
    };
    transfer::share_object(config)
  }
  
  public(friend) fun register_collateral_type<T>(
    self: &mut CollateralConfig,
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
  ) {
    vector::push_back(&mut self.collateralTypes, get<T>());
    table::add(
      &mut self.collateralFactorTable,
      get<T>(),
      exponential::exp(collateralFactorEnu, collateralFactorDeno)
    )
  }
  
  public fun collateral_factor(
    self: &CollateralConfig,
    typeName: TypeName,
  ): Exp {
    let hasFactor = table::contains(&self.collateralFactorTable, typeName);
    if (hasFactor == true) {
      let factor = table::borrow(&self.collateralFactorTable, typeName);
      assert!(exponential::truncate(*factor) == 0, ECollateralFactoryTooBig);
      *factor
    } else {
      exponential::exp(0u128, 1u128)
    }
  }
  
  public fun collateral_types(self: &CollateralConfig): &vector<TypeName> {
    &self.collateralTypes
  }
  
  public fun collateral_factor_table(self: &CollateralConfig): &Table<TypeName, Exp> {
    &self.collateralFactorTable
  }
}
