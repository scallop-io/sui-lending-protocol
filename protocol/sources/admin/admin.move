module protocol::admin {
  
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  
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
}
