module protocol::open_obligation {
  
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use protocol::obligation::{Self, ObligationKey};
  
  public entry fun open_obligation(ctx: &mut TxContext) {
    let obligationKey = open_obligation_(ctx);
    transfer::transfer(obligationKey, tx_context::sender(ctx))
  }
  
  public fun open_obligation_(
    ctx: &mut TxContext
  ): ObligationKey {
    let (obligation, obligationKey) = obligation::new(ctx);
    transfer::share_object(obligation);
    obligationKey
  }
}
