module protocol::open_obligation {

  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use protocol::obligation::{Self, ObligationKey, Obligation};

  /// A hot potato is a temporary object that is passed around between parties
  /// It is used to ensure that obligations are always shared in a transaction
  struct ObligationHotPotato {
    obligation_id: ID, 
  }

  const EInvalidObligation: u64 = 0x10000;

  /// Create a new obligation and share it
  /// At the same time, the obligation key is transferred to the sender
  public entry fun open_obligation_entry(ctx: &mut TxContext) {
    let (obligation, obligation_key) = obligation::new(ctx);
    transfer::public_transfer(obligation_key, tx_context::sender(ctx));
    transfer::public_share_object(obligation);
  }
  
  /// create a new obligation and obligation key object and take it
  /// this function offers flexibility by leveraging the uses of programmability on Sui
  public fun open_obligation(ctx: &mut TxContext): (Obligation, ObligationKey, ObligationHotPotato) {
    let (obligation, obligation_key) = obligation::new(ctx);
    let obligation_hot_potato = ObligationHotPotato {
      obligation_id: object::id(&obligation),
    };
    (obligation, obligation_key, obligation_hot_potato)
  }

  /// return the obligation with the obligation hot potato
  /// this function makes sure that the obligation is returned with the obligation hot potato
  /// So that the obligation is always shared in a transaction
  public fun return_obligation(obligation: Obligation, obligation_hot_potato: ObligationHotPotato, ctx: &mut TxContext) {
    let ObligationHotPotato { obligation_id } = obligation_hot_potato;
    assert!(obligation_id == object::id(&obligation), EInvalidObligation);
    transfer::public_share_object(obligation);
  }
}
