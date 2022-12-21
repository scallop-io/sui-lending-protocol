/// Each new bank need to be registerred before create
/// In order to make sure only one bank will be created per underlying coin
module mobius_core::bank_registry {
  
  use std::type_name::{get};
  use sui::tx_context::TxContext;
  use registry::registry::{Self, Registry};
  use mobius_core::bank::Bank;
  
  friend mobius_core::admin;
  
  struct BankRegistry has drop {}
  
  fun init(ctx: &mut TxContext) {
    registry::create_registry(BankRegistry {}, ctx);
  }
  
  // make sure only one bank per underlying coin
  public(friend) fun register_bank<T>(
    registry: &mut Registry<BankRegistry>,
    bank: &Bank<T>,
  ) {
    let typeName = get<T>();
    registry::register(BankRegistry {}, registry, typeName, bank);
  }
}
