module mobius_core::admin {
  
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use sui::coin::TreasuryCap;
  use mobius_core::bank;
  use mobius_core::bank_registry::{Self, BankRegistry};
  
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
  fun create_bank<UnderlyingCoin, BankCoin: drop>(
    _: &AdminCap,
    treasuryCap: TreasuryCap<BankCoin>,
    bankRegistry: &mut BankRegistry,
    ctx: &mut TxContext
  ) {
    let bank = bank::new<UnderlyingCoin, BankCoin>(treasuryCap, ctx);
    // This makes sure only one bank will ever be created for each UnderlyingCoin
    bank_registry::register_bank(bankRegistry, &bank);
    transfer::share_object(bank);
  }
}
