module mobius_protocol::admin {
  
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use mobius_protocol::bank;
  use mobius_protocol::bank_registry::{Self, BankRegistry};
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
}
