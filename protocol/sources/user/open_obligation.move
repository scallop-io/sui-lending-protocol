module protocol::open_obligation {
  
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use protocol::obligation::{Self, ObligationKey, Obligation};
  use sui::object::{Self, ID};

  struct ObligationWrapper { 
    obligation_id: ID, 
    obligation_key_id: ID
  }

  const EInvalidObligation: u64 = 0x10000;
  const EInvalidObligationKey: u64 = 0x10001;
  
  public entry fun open_obligation_entry(ctx: &mut TxContext) {
    let (obligation, obligation_key) = obligation::new(ctx);
    transfer::public_transfer(obligation_key, tx_context::sender(ctx));
    transfer::public_share_object(obligation);
  }
  
  /// create a new obligation and obligation key object and take it
  /// this function offers flexibility by leveraging the uses of programmability on Sui
  public fun create_and_take_obligation(ctx: &mut TxContext): (Obligation, ObligationKey, ObligationWrapper) {
    let (obligation, obligation_key) = obligation::new(ctx);
    let obligation_wrapper = ObligationWrapper {
      obligation_id: object::id(&obligation),
      obligation_key_id: object::id(&obligation_key),
    };

    (obligation, obligation_key, obligation_wrapper)
  }
 
  public fun return_obligation(obligation: Obligation, obligation_key: ObligationKey, obligation_wrapper: ObligationWrapper, ctx: &mut TxContext) {
    let ObligationWrapper { obligation_id, obligation_key_id } = obligation_wrapper;

    assert!(obligation_id == object::id(&obligation), EInvalidObligation);
    assert!(obligation_key_id == object::id(&obligation_key), EInvalidObligationKey);

    transfer::public_transfer(obligation_key, tx_context::sender(ctx));
    transfer::public_share_object(obligation);
  }
}
