/// @title This module is dedicated for creating new obligations
/// @author Scallop Labs
/// @notice Offer 2 ways of creating obligation:
///   1. Create a fresh obligation with one method call
///   2. Create an obligation and hot potato, and call another method to consume the hot poato and share the obligation
///   Either way, the obligation will become a shared object even actually.
module protocol::open_obligation {

  use sui::event::emit;
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, ID};
  use protocol::obligation::{Self, ObligationKey, Obligation};
  use protocol::version::{Self, Version};
  use protocol::error;

  /// A hot potato is a temporary object that is passed around between parties
  /// It is used to ensure that obligations are always shared in a transaction
  struct ObligationHotPotato {
    obligation_id: ID, 
  }

  struct ObligationCreatedEvent has copy, drop {
    sender: address,
    obligation: ID,
    obligation_key: ID,
  }

  /// @notice Create a new obligation and transfer the obligation key to the sender
  /// @dev the obaligation object will be a shared object, object key is the proof of ownership for the obligation
  /// @param version The version control object, contract version must match with this
  /// @param ctx The SUI transaction context object
  #[allow(lint(share_owned))]
  public entry fun open_obligation_entry(version: &Version, ctx: &mut TxContext) {
    // Check version
    version::assert_current_version(version);
    let (obligation, obligation_key) = obligation::new(ctx);

    // Emit the obligation created event
    emit(ObligationCreatedEvent {
      sender: tx_context::sender(ctx),
      obligation: object::id(&obligation),
      obligation_key: object::id(&obligation_key),
    });

    // Transfer the obligation key to the sender
    transfer::public_transfer(obligation_key, tx_context::sender(ctx));

    // Share the obligation object
    transfer::public_share_object(obligation);
  }
  
  /// @notice create a new obligation, together with a hot potato
  /// @dev this function offers flexibility to let user do other actions with the obligation in the same transaction.
  /// @param version The version control object, contract version must match with this
  /// @param ctx The SUI transaction context object
  /// @return Obligation, ObligationKey, and a hot potato to enforce sharing of obligation.
  public fun open_obligation(version: &Version, ctx: &mut TxContext): (Obligation, ObligationKey, ObligationHotPotato) {
    // Check contract version
    version::assert_current_version(version);

    let (obligation, obligation_key) = obligation::new(ctx);
    let obligation_hot_potato = ObligationHotPotato {
      obligation_id: object::id(&obligation),
    };

    // Emit the obligation created event
    emit(ObligationCreatedEvent {
      sender: tx_context::sender(ctx),
      obligation: object::id(&obligation),
      obligation_key: object::id(&obligation_key),
    });

    // Return the obligation, obligation key and the hot potato
    (obligation, obligation_key, obligation_hot_potato)
  }

  /// @notice share the obligation and consume the hot potato created
  /// @dev this function makes sure that the obligation is always shared
  /// @param version The version control object, contract version must match with this
  /// @param obligation the obligation to be shared
  /// @param obligation_hot_potato the hot potato object created together with the obligation
  #[allow(lint(share_owned))]
  public fun return_obligation(version: &Version, obligation: Obligation, obligation_hot_potato: ObligationHotPotato) {
    // Check contract version
    version::assert_current_version(version);
    // Make sure the obligation hot potato is for the obligation
    let ObligationHotPotato { obligation_id } = obligation_hot_potato;
    assert!(obligation_id == object::id(&obligation), error::invalid_obligation_error());
    // Share the obligation
    transfer::public_share_object(obligation);
  }
}
