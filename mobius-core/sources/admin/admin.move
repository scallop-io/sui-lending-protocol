module mobius_core::admin {
  
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use mobius_core::bank;
  use mobius_core::bank_registry::{Self, BankRegistry};
  use mobius_core::collateral_config;
  use mobius_core::collateral_config::CollateralConfig;
  use registry::registry::Registry;
  
  struct AdminCap has key, store {
    id: UID
  }
  
  fun init(ctx: &mut TxContext) {
    let adminCap = AdminCap { id: object::new(ctx) };
    transfer::transfer(
      adminCap,
      tx_context::sender(ctx)
    )
  }
  
  /// Create a bank to borrow and lend asset, only admin
  /// Only one bank per UnderlyingCoin
  public entry fun create_bank<T>(
    _: &AdminCap,
    bankRegistry: &mut Registry<BankRegistry>,
    ctx: &mut TxContext
  ) {
    let bank = bank::new<T>(ctx);
    // This makes sure only one bank will ever be created for each UnderlyingCoin
    bank_registry::register_bank(bankRegistry, &bank);
    transfer::share_object(bank);
  }
  
  public entry fun add_collateral_type<T>(
    _: &AdminCap,
    collateralConfig: &mut CollateralConfig,
    collateralFactorEnu: u128,
    collateralFactorDeno: u128,
  ) {
    collateral_config::register_collateral_type<T>(
      collateralConfig,
      collateralFactorEnu,
      collateralFactorDeno
    )
  }
}
