module protocol::open_position {
  
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use protocol::position::{Self, PositionKey};
  
  public entry fun open_position(ctx: &mut TxContext) {
    let positionKey = open_position_(ctx);
    transfer::transfer(positionKey, tx_context::sender(ctx))
  }
  
  public fun open_position_(
    ctx: &mut TxContext
  ): PositionKey {
    let (position, positionKey) = position::new(ctx);
    transfer::share_object(position);
    positionKey
  }
}
