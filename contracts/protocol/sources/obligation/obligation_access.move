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

  #[test_only]
  public fun init_test(ctx: &mut TxContext) {
    init(ctx);
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

  #[test_only]
  use sui::test_scenario;

  #[test_only]
  struct MockKeyA has drop {}

  #[test_only]
  struct MockKeyB has drop {}
  
  #[test_only]
  struct MockKeyC has drop {}

  #[test]
  fun lock_key_test() {
    let admin = @0x1;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

    add_lock_key<MockKeyA>(&mut obligation_access_store);
    add_lock_key<MockKeyB>(&mut obligation_access_store);
    add_lock_key<MockKeyC>(&mut obligation_access_store);

    assert_lock_key_in_store(&obligation_access_store, MockKeyA {});
    assert_lock_key_in_store(&obligation_access_store, MockKeyB {});
    assert_lock_key_in_store(&obligation_access_store, MockKeyC {});

    assert!(vec_set::size(&obligation_access_store.lock_keys) == 3, 0);

    remove_lock_key<MockKeyA>(&mut obligation_access_store);
    remove_lock_key<MockKeyB>(&mut obligation_access_store);
    remove_lock_key<MockKeyC>(&mut obligation_access_store);

    assert!(vec_set::size(&obligation_access_store.lock_keys) == 0, 0);

    test_scenario::return_shared(obligation_access_store);
    test_scenario::end(scenario_value);
  }

  #[test]
  fun reward_key_test() {
    let admin = @0x1;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    init_test(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let obligation_access_store = test_scenario::take_shared<ObligationAccessStore>(scenario);

    add_reward_key<MockKeyA>(&mut obligation_access_store);
    add_reward_key<MockKeyB>(&mut obligation_access_store);
    add_reward_key<MockKeyC>(&mut obligation_access_store);

    assert_reward_key_in_store(&obligation_access_store, MockKeyA {});
    assert_reward_key_in_store(&obligation_access_store, MockKeyB {});
    assert_reward_key_in_store(&obligation_access_store, MockKeyC {});

    assert!(vec_set::size(&obligation_access_store.reward_keys) == 3, 0);

    remove_reward_key<MockKeyA>(&mut obligation_access_store);
    remove_reward_key<MockKeyB>(&mut obligation_access_store);
    remove_reward_key<MockKeyC>(&mut obligation_access_store);

    assert!(vec_set::size(&obligation_access_store.reward_keys) == 0, 0);

    test_scenario::return_shared(obligation_access_store);
    test_scenario::end(scenario_value);
  }
}
