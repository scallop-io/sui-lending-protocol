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
  use sui::tx_context::TxContext;
  use sui::transfer;
  use math::u64;
  use sui::dynamic_field;

  friend protocol::app;
  friend protocol::borrow;

  // This is the base for calculating the fee for borrowing and referral
  const BASE_FOR_FEE: u64 = 100;

  // Error codes
  const ERROR_NOT_AUTHORIZED: u64 = 711;
  const ERROR_FEE_DISCOUNT_TOO_HIGH: u64 = 712;
  const ERROR_CFG_ALREADY_EXIST: u64 = 713;
  const ERROR_CFG_ISNT_EXIST: u64 = 714;

  // This is a hot potato object, which can only be consumed by the authorized package
  #[allow(lint(missing_key))]
  struct BorrowReferral<phantom CoinType, Witness> {
    id: UID, // this is supposed to be a hot potato object, `id` field here just to help adding a dynamic_field
    borrow_fee_discount: u64, // The percentage of the borrow fee that will be discounted for the borrower
    referral_share: u64, // The percentage of the borrow fee that will be shared with the referrer
    borrowed: u64, // This field is abandoned, use the dynamic field `BorrowedKey`
    referral_fee: Balance<CoinType>, // This field is abandoned, use the dynamic field `ReferralFeeKey`
    witness: Witness
  }

  // This is the dynamic field key to store the config data on the borrow referral object
  // Usually, the authorized package needs to store some custom data on the borrow referral object
  struct BorrowReferralCfgKey<phantom Cfg> has copy, store, drop {}

  // This is the dynamic field key to store the borrowed amount on the borrow referral object
  // The original borrowed field is discarded because of the `increase_borrowed` method security issue
  struct BorrowedKey has copy, store, drop {}

  // This is the dynamic field key to store the referral fe on the borrow referral object
  // The
  struct ReferralFeeKey has copy, store, drop {}

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
    let borrowed = dynamic_field::borrow<BorrowedKey, u64>(&borrow_referral.id, BorrowedKey {});
    *borrowed
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
    let borrow_referral = BorrowReferral {
      id: object::new(ctx),
      borrowed: 0,
      borrow_fee_discount,
      referral_share,
      referral_fee: balance::zero<CoinType>(),
      witness
    };

    // Attach the dynamic fields: borrowed, referralFee.
    dynamic_field::add(&mut borrow_referral.id, BorrowedKey {}, 0);
    dynamic_field::add(&mut borrow_referral.id, ReferralFeeKey {}, balance::zero<CoinType>());

    // Return the borrow referral object
    borrow_referral
  }

  /// @notice Calculate the borrow fee after applying the discount, if discount is 90, the fee will be 90% of the original fee
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

  /// @deprecated This function should be protected.
  public fun put_referral_fee<CoinType, Witness: drop>(
    _borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    _referral_fee: Balance<CoinType>,
  ) {
    abort 0
  }

  public(friend) fun put_referral_fee_v2<CoinType, Witness: drop>(
    borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    referral_fee: Balance<CoinType>,
  ) {
    let borrow_referral_fee_mut = dynamic_field::borrow_mut<ReferralFeeKey, Balance<CoinType>>(&mut borrow_referral.id, ReferralFeeKey {});
    balance::join(borrow_referral_fee_mut, referral_fee);
  }

  /// @deprecated This function should be protected.
  public fun increase_borrowed<CoinType, Witness: drop>(
    _borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    _borrowed: u64
  ) {
    abort 0
  }

  public(friend) fun increase_borrowed_v2<CoinType, Witness: drop>(
    borrow_referral: &mut BorrowReferral<CoinType, Witness>,
    borrowed: u64
  ) {
    let borrowed_mut = dynamic_field::borrow_mut<BorrowedKey, u64>(&mut borrow_referral.id, BorrowedKey {});
    *borrowed_mut = *borrowed_mut + borrowed;
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
    assert!(dynamic_field::exists_(&borrow_referral.id, BorrowReferralCfgKey<Cfg> {}) == false, ERROR_CFG_ALREADY_EXIST);
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
    assert!(dynamic_field::exists_(&borrow_referral.id, BorrowReferralCfgKey<Cfg> {}), ERROR_CFG_ISNT_EXIST);
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
    // Get referral fee from dynamic fields
    let patched_referral_fee = dynamic_field::remove<ReferralFeeKey, Balance<CoinType>>(&mut borrow_fee_referral.id, ReferralFeeKey {});

    // Delete the object
    let BorrowReferral {
      id,
      borrowed: abandoned_borrowed,
      borrow_fee_discount: _,
      referral_share: _,
      witness: _,
      referral_fee: abandoned_referral_fee,
    } = borrow_fee_referral;
    object::delete(id);

    // Make sure the abandoned fields are not touched
    if (balance::value(&abandoned_referral_fee) > 0 || abandoned_borrowed > 0) {
      abort 0
    };
    // Destroy the abandoned referral fee value
    balance::destroy_zero(abandoned_referral_fee);

    // Return the referral fee getting from the dynamic field
    patched_referral_fee
  }

  /// @notice Make sure the caller is an authorized package
  /// @custom:Witness The type of the witness issued by the authorized package
  public fun assert_authorized_witness<Witness: drop>(
    authorized_witness_list: &AuthorizedWitnessList,
  ) {
    let is_authorized = vec_set::contains(&authorized_witness_list.witness_list, &type_name::get<Witness>());
    assert!(is_authorized, ERROR_NOT_AUTHORIZED)
  }

  // ================ For managing the witness of referral =============== //

  /// @notice Adding authorized referral package
  /// @dev This is meant to be called by the admin of Scallop
  /// @custom:Witness The type of the witness issued by the authorized package
  public(friend) fun add_witness<Witness: drop>(
    authorized_witness_list: &mut AuthorizedWitnessList,
  ) {
    let witness_type = type_name::get<Witness>();
    if (vec_set::contains(&authorized_witness_list.witness_list, &witness_type) == false) {
      vec_set::insert(
        &mut authorized_witness_list.witness_list,
        witness_type
      );
    };
  }

  /// @notice Removing authorized referral package
  /// @dev This is meant to be called by the admin of Scallop
  /// @custom:Witness The type of the witness issued by the authorized package
  public(friend) fun remove_witness<Witness: drop>(
    authorized_witness_list: &mut AuthorizedWitnessList,
  ) {
    let witness_type = type_name::get<Witness>();
    if (vec_set::contains(&authorized_witness_list.witness_list, &witness_type) == true) {
      vec_set::remove(
        &mut authorized_witness_list.witness_list,
        &witness_type
      );
    };
  }

  /// @notice Creating the witness list
  /// @dev The admin need to make sure only call this function for once
  /// @custom:Witness The type of the witness issued by the authorized package
  public(friend) fun create_witness_list(ctx: &mut TxContext) {
    let witness_list = AuthorizedWitnessList {
      id: object::new(ctx),
      witness_list: vec_set::empty()
    };
    transfer::share_object(witness_list);
  }
}
