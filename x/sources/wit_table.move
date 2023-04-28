/// Witness controlled table
/// Witness is required to write or destory
/// Read is open to anyone
module x::wit_table {
  use sui::object::{Self, UID};
  use sui::table::{Self, Table};
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context::TxContext;
  use std::option;
  use std::vector;
  
  /// A data structure backed by sui::table and sui::vec_set.
  /// All write operations are controlled by witness pattern
  /// If you set withKeys = true when creating table:
  /// It will store all the keys in a vector, with which you can use to loop the table.
  /// The keys are in insertion order.
  struct WitTable<phantom T: drop, K: copy + drop + store, phantom V: store> has key, store {
    id: UID,
    table: Table<K, V>,
    keys: option::Option<VecSet<K>>,
    with_keys: bool
  }
  
  /// Creates a new, empty table
  public fun new<T: drop, K: copy + drop + store, V: store>(
    _: T,
    with_keys: bool,
    ctx: &mut TxContext
  ): WitTable<T, K, V> {
    let keys = if (with_keys) {
      option::some(vec_set::empty<K>())
    }  else {
      option::none()
    };
    WitTable {
      id: object::new(ctx),
      table: table::new(ctx),
      keys,
      with_keys
    }
  }
  
  /// Adds a key-value pair to the table.
  /// Aborts if the xtable already has an entry with that key `k: K`.
  /// Wtiness control
  public fun add<T: drop, K: copy + drop + store, V: store>(
    _: T,
    self: &mut WitTable<T, K, V>,
    k: K, v: V
  ) {
    table::add(&mut self.table, k, v);
    if (self.with_keys) {
      let keys = option::borrow_mut(&mut self.keys);
      vec_set::insert(keys, k);
    }
  }
  
  /// Return: vector of all the keys
  /// Empty if withKeys = false
  public fun keys<T: drop, K: copy + drop + store, V: store>(
    self: &WitTable<T, K, V>,
  ): vector<K> {
    if (self.with_keys) {
      let keys = option::borrow(&self.keys);
      vec_set::into_keys(*keys)
    } else {
      vector::empty()
    }
  }
  
  /// Immutable borrows the value associated with the key in the table.
  /// Aborts if the table does not have an entry with that key `k: K`.
  /// Permissionless
  public fun borrow<T: drop, K: copy + drop + store, V: store>(
    self: &WitTable<T, K, V>,
    k: K
  ): &V {
    table::borrow(&self.table, k)
  }
  
  /// Mutably borrows the value associated with the key in the table.
  /// Aborts if the table does not have an entry with that key `k: K`.
  /// Witness control
  public fun borrow_mut<T: drop, K: copy + drop + store, V: store>(
    _: T,
    self: &mut WitTable<T, K, V>,
    k: K
  ): &mut V {
    table::borrow_mut(&mut self.table, k)
  }
  
  /// Mutably borrows the key-value pair in the table and returns the value.
  /// Aborts if the table does not have an entry with that key `k: K`.
  /// Witness control
  public fun remove<T: drop, K: copy + drop + store, V: store>(
    _: T,
    self: &mut WitTable<T, K, V>,
    k: K
  ): V {
    if (self.with_keys) {
      let keys = option::borrow_mut(&mut self.keys);
      vec_set::remove(keys, &k);
    };
    table::remove(&mut self.table, k)
  }
  
  /// Returns true if there is a value associated with the key `k: K` in table
  /// Permisionless
  public fun contains<T: drop, K: copy + drop + store, V: store>(
    self: &WitTable<T, K, V>,
    k: K
  ): bool {
    table::contains(&self.table, k)
  }
  
  /// Returns the size of the table, the number of key-value pairs
  /// Permisionless
  public fun length<T: drop, K: copy + drop + store, V: store>(
    self: &WitTable<T, K, V>,
  ): u64 {
    table::length(&self.table)
  }
  
  /// Returns true if the table is empty (if `length` returns `0`)
  /// Permisionless
  public fun is_empty<T: drop, K: copy + drop + store, V: store>(
    self: &WitTable<T, K, V>
  ): bool {
    table::is_empty(&self.table)
  }
  
  /// Destroys an empty table
  /// Aborts if the table still contains values
  /// Witness control
  public fun destroy_empty<T: drop, K: copy + drop + store, V: store>(
    _: T,
    self: WitTable<T, K, V>
  ) {
    let WitTable { id, table, keys: _, with_keys: _ } = self;
    table::destroy_empty(table);
    object::delete(id);
  }
  
  /// Drop a possibly non-empty table.
  /// Usable only if the value type `V` has the `drop` ability
  /// Witness control
  public fun drop<T: drop, K: copy + drop + store, V: drop + store>(
    _: T,
    self: WitTable<T, K, V>
  ) {
    let WitTable { id, table, keys: _, with_keys: _ } = self;
    table::drop(table);
    object::delete(id);
  }
}
