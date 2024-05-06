/// @title An extention which let external authorized package to customize the referral fee & borrow fee discount for user
/// @author Scallop Labs
/// @dev Create a `BorrowReferral` object, pass it to borrow function, the discount will be applied to the borrower,
///         and the referral revenue will be put into the `referral_revenue` field of the BorrowReferral object.
///         Later in the authorized package will be responsible for distributing the referral revenue to the referrer.
module protocol::borrow_referral {

  use std::type_name::{Self, TypeName};
  use sui::balance;
  use sui::object::{Self, UID};
  use sui::vec_set::{Self, VecSet};
  use sui::balance::Balance;
  use sui::coin::balance;
  use sui::tx_context::TxContext;
  use sui::transfer;
  use math::u64;
  use sui::dynamic_field;
  use sui::dynamic_object_field;

  // This is the base for calculating the fee for borrowing and referral
  const BASE_FOR_FEE: u64 = 100;

  // Error codes
  const ERROR_NOT_AUTHORIZED: u64 = 711;
  const ERROR_FEE_DISCOUNT_TOO_HIGH: u64 = 712;

  // This is a hot potato object, which can only be consumed by the authorized package
  struct BorrowReferral<phantom CoinType, Witness> {
    id: UID,
    borrow_fee_discount: u64, // The percentage of the borrow fee that will be discounted for the borrower
    referral_share: u64, // The percentage of the borrow fee that will be shared with the referrer
    borrowed: u64, // The amount of coin borrowed using this referral object
    referral_fee: Balance<CoinType>,
    witness: Witness
  }

  // This is the dynamic field key to store the config data on the borrow referral object
  // Usually, the authorized package needs to store some custom data on the borrow referral object
  struct BorrowReferralCfgKey<phantom Cfg> has copy, store, drop {}

  // This object manages the list of authorized package types
  struct AuthorizedWitnessList has key {
    id: UID,
    witness_list: VecSet<TypeName>
  }

  // ================= Read methods =============== //
  public fun  borrow_fee_discount<CoinType, Witness>(borrow_referral: &BorrowReferral<CoinType, Witness>): u64 {
    borrow_referral.borrow_fee_discount
  }

  public fun borrowed<CoinType, Witness>(borrow_referral: &BorrowReferral<CoinType, Witness>): u64 {
    borrow_referral.borrowed
  }

  public fun referral_share<CoinType, Witness>(borrow_referral: &BorrowReferral<CoinType, Witness>): u64 {
    borrow_referral.referral_share
  }

  public fun fee_rate_base(): u64 {
    BASE_FOR_FEE
  }


  /// @notice Intialize the authorized witness list with an empty list
  fun init(ctx: &mut TxContext) {
    let witness_list = AuthorizedWitnessList {
      id: object::new(ctx),
      witness_list: vec_set::empty()
    };
    transfer::share_object(witness_list);
  }

  /// @notice Create a borrow referral object
  /// @dev This is meant to be called by the authorized package to create a borrow referral object to pass to the borrow function
  /// @param witness The witness issued by the authorized package
  /// @param authorized_witness_list The authorized witness list object
  /// @param borrower_discount The percentage of the borrow fee that will be discounted for the borrower, base 100, 90 means 90%
  /// @param referral_share The percentage of the borrow fee that will be shared with the referrer, base 100, 10 means 10%
  /// @param ctx The SUI transaction context object
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun create_borrow_referral<CoinType, Witness: drop>(
    witness: Witness,
    authorized_witness_list: &AuthorizedWitnessList,
    borrow_fee_discount: u64,
    referral_share: u64,
    ctx: &mut TxContext
  ): BorrowReferral<CoinType, Witness> {
    // Make sure the caller is an authorized package
    assert_authorized_witness<Witness>(authorized_witness_list);

    // Make sure the borrow fee discount + referral_share is less than 100%
    assert!(borrow_fee_discount + referral_share < BASE_FOR_FEE, ERROR_FEE_DISCOUNT_TOO_HIGH);

    // Create the referral object
    BorrowReferral {
      id: object::new(ctx),
      borrowed: 0,
      borrow_fee_discount,
      referral_share,
      referral_fee: balance::zero<CoinType>(),
      witness
    }
  }

  /// @notice Calculate the borrow fee after applying the discount, if discount is 90, the fee will be 90% of the original fee
  /// @dev This is meant to called by the borrow function to calculate the discounted borrow fee
  /// @param borrow_referral The borrow referral object
  /// @param original_borrow_fee The original borrow fee before discount
  /// @return The discounted borrow fee amount
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun calc_discounted_borrow_fee<CoinType, Witness: drop>(
    borrow_referral: &BorrowReferral<CoinType, Witness>,
    original_borrow_fee: u64,
  ): u64 {
    u64::mul_div(original_borrow_fee, borrow_referral.borrow_fee_discount, BASE_FOR_FEE)
  }

  /// @notice Calculate the referral fee, which is the share of the borrow fee that will be shared with the referrer
  /// @dev This is meant to called by the borrow function to calculate the referral fee
  /// @param borrow_referral The borrow referral object
  /// @param original_borrow_fee The original borrow fee before discount
  /// @return The referral fee amount
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun calc_referral_fee<CoinType, Witness: drop>(
    borrow_referral: &BorrowReferral<CoinType, Witness>,
    original_borrow_fee: u64,
  ): u64 {
    u64::mul_div(original_borrow_fee, borrow_referral.referral_share, BASE_FOR_FEE)
  }

  /// @notice Put the referral fee into the borrow referral object
  /// @dev This is meant to called by the borrow function to put the referral fee into the borrow referral object
  /// @param borrow_referral The borrow referral object
  /// @param referral_fee The referral fee
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun put_referral_fee<CoinType, Witness: drop>(
    borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    referral_fee: Balance<CoinType>,
  ) {
    balance::join(&mut borrow_referral.referral_fee, referral_fee);
  }

  /// @notice Add a custom config data to the borrow referral object
  /// @dev This is meant to be called by the authorized package to add custom config data to the borrow referral object
  /// @param borrow_referral The borrow referral object
  /// @param cfg The custom config data
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  /// @custom:Cfg The type of the custom config data
  public fun add_referral_cfg<CoinType, Witness: drop, Cfg: store + drop>(
    borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    cfg: Cfg
  ) {
    dynamic_field::add(&mut borrow_referral.id, BorrowReferralCfgKey<Cfg> {}, cfg);
  }

  /// @notice Get the custom config data from the borrow referral object
  /// @dev This is meant to be called by the authorized package to get the custom config data from the borrow referral object
  /// @param borrow_referral The borrow referral object
  /// @return The custom config data
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  /// @custom:Cfg The type of the custom config data
  public fun get_referral_cfg<CoinType, Witness: drop, Cfg: store + drop>(
    borrow_referral: &BorrowReferral<CoinType, Witness>,
  ): &Cfg {
    dynamic_field::borrow(&borrow_referral.id, BorrowReferralCfgKey<Cfg> {})
  }

  /// @notice Destroy the borrow referral object
  /// @dev This is meant to be called by the authorized package to destroy the borrow referral object, and retrive the referral fee
  ///      Also, the witness passed in need to be the same type as the witness issued by the authorized package
  /// @param borrow_referral The borrow referral object
  /// @return The referral fee
  /// @custom:CoinType The type of the coin to borrow
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun destroy_borrow_referral<CoinType, Witness: drop>(
    _: Witness,
    borrow_fee_referral: BorrowReferral<CoinType, Witness>,
  ): Balance<CoinType> {
    // Delete the object
    let BorrowReferral {
      id,
      borrowed: _,
      borrow_fee_discount: _,
      referral_share: _,
      witness: _,
      referral_fee,
    } = borrow_fee_referral;
    object::delete(id);

    referral_fee
  }

  /// @notice Make sure the caller is an authorized package
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun assert_authorized_witness<Witness: drop>(
    authorized_witness_list: &AuthorizedWitnessList,
  ) {
    let is_authorized = vec_set::contains(&authorized_witness_list.witness_list, &type_name::get<Witness>());
    assert!(is_authorized, ERROR_NOT_AUTHORIZED)
  }
}
