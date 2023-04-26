/// TODO: add events for obligation
module protocol::open_obligation {

  use sui::event::emit;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use protocol::obligation::{Self, ObligationKey, Obligation};

  /// A hot potato is a temporary object that is passed around between parties
  /// It is used to ensure that obligations are always shared in a transaction
  struct ObligationHotPotato {
    obligation_id: ID, 
  }

  const EInvalidObligation: u64 = 0x50001;

  struct ObligationCreatedEvent has copy, drop {
    sender: address,
    obligation: ID,
    obligation_key: ID,
  }

  /// Create a new obligation and share it
  /// At the same time, the obligation key is transferred to the sender
  public entry fun open_obligation_entry(ctx: &mut TxContext) {
    let (obligation, obligation_key) = obligation::new(ctx);

    emit(ObligationCreatedEvent {
      sender: tx_context::sender(ctx),
      obligation: object::id(&obligation),
      obligation_key: object::id(&obligation_key),
    });

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
    
    emit(ObligationCreatedEvent {
      sender: tx_context::sender(ctx),
      obligation: object::id(&obligation),
      obligation_key: object::id(&obligation_key),
    });

    (obligation, obligation_key, obligation_hot_potato)
  }

  /// return the obligation with the obligation hot potato
  /// this function makes sure that the obligation is returned with the obligation hot potato
  /// So that the obligation is always shared in a transaction
  public fun return_obligation(obligation: Obligation, obligation_hot_potato: ObligationHotPotato) {
    let ObligationHotPotato { obligation_id } = obligation_hot_potato;
    assert!(obligation_id == object::id(&obligation), EInvalidObligation);
    transfer::public_share_object(obligation);
  }
}
