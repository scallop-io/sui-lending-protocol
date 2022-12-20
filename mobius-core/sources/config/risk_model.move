/// Risk model for coin
/// TODO: implement this placeholder
module mobius_core::risk_model {
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  
  struct RiskModel<phantom T> has key {
    id: UID,
    collateralRate: u64,
  }
  
  /// only admin
  public (friend) fun new<T>(ctx: &mut TxContext): RiskModel<T> {
    RiskModel<T> {
      id: object::new(ctx),
      collateralRate: 0,
    }
  }
}
