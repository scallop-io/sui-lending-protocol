/// Each new bank need to be registerred before create
/// In order to make sure only one bank will be created per underlying coin
module mobius_core::bank_registry {
  
  use sui::tx_context::TxContext;
  
  use sui::transfer;
  use mobius_core::bank::Bank;
  use sui::object::{UID, ID};
  use sui::table::Table;
  use std::type_name::{TypeName, get};
  use sui::object;
  use sui::table;
  
  friend mobius_core::admin;
  
  struct BankRegistry has key {
    id: UID,
    registryTable: Table<TypeName, ID>
  }
  
  fun init(ctx: &mut TxContext) {
    let bankRegistry = BankRegistry {
      id: object::new(ctx),
      registryTable: table::new(ctx)
    };
    transfer::share_object(bankRegistry);
  }
  
  // make sure only one bank per underlying coin
  public(friend) fun register_bank<UnderlyingCoin, BankCoin>(
    registry: &mut BankRegistry,
    bank: &Bank<UnderlyingCoin, BankCoin>,
  ) {
    let typeName = get<UnderlyingCoin>();
    table::add(&mut registry.registryTable, typeName, object::id(bank))
  }
}
