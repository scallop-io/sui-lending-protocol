module protocol::obligation_access {

  use std::type_name::{Self, TypeName};
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context::TxContext;
  use sui::transfer;
  use sui::object::{Self, UID};
  use protocol::error;

  friend protocol::app;

  /// This is controlled by the admin.
  /// The admin can add or remove lock keys and reward keys.
  /// Obligation can only choose the keys in the store.
  struct ObligationAccessStore has key, store {
    id: UID,
    lock_keys: VecSet<TypeName>,
    reward_keys: VecSet<TypeName>,
  }

  /// Make a single shared `ObligationAccessStore` object.
  fun init(ctx: &mut TxContext) {
    let store = ObligationAccessStore {
      id: object::new(ctx),
      lock_keys: vec_set::empty(),
      reward_keys: vec_set::empty(),
    };
    transfer::share_object(store);
  }

  /// ====== Obligation Access Store ======

  /// Add a lock key to the store.
  public(friend) fun add_lock_key<T: drop>(self: &mut ObligationAccessStore) {
    let key = type_name::get<T>();
    assert!(!vec_set::contains(&self.lock_keys, &key), error::obligation_access_store_key_exists());
    vec_set::insert(&mut self.lock_keys, key);
  }

  /// Remove a lock key from the store.
  public(friend) fun remove_lock_key<T: drop>(self: &mut ObligationAccessStore) {
    let key = type_name::get<T>();
    assert!(vec_set::contains(&self.lock_keys, &key), error::obligation_access_store_key_not_found());
    vec_set::remove(&mut self.lock_keys, &key);
  }

  /// Add a reward key to the store.
  public(friend) fun add_reward_key<T: drop>(self: &mut ObligationAccessStore) {
    let key = type_name::get<T>();
    assert!(!vec_set::contains(&self.reward_keys, &key), error::obligation_access_store_key_exists());
    vec_set::insert(&mut self.reward_keys, key);
  }

  /// Remove a reward key from the store.
  public(friend) fun remove_reward_key<T: drop>(self: &mut ObligationAccessStore) {
    let key = type_name::get<T>();
    assert!(vec_set::contains(&self.reward_keys, &key), error::obligation_access_store_key_not_found());
    vec_set::remove(&mut self.reward_keys, &key);
  }

  /// Make sure the lock key is in the store.
  public fun assert_lock_key_in_store<T: drop>(store: &ObligationAccessStore, _: T) {
    let key = type_name::get<T>();
    assert!(vec_set::contains(&store.lock_keys, &key), error::obligation_access_lock_key_not_in_store());
  }

  /// Make sure the reward key is in the store.
  public fun assert_reward_key_in_store<T: drop>(store: &ObligationAccessStore, _: T) {
    let key = type_name::get<T>();
    assert!(vec_set::contains(&store.reward_keys, &key), error::obligation_access_reward_key_not_in_store());
  }
}
