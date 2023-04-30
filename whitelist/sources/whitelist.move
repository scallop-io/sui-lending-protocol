module whitelist::whitelist {

  use sui::dynamic_field as df;
  use sui::object::UID;
  use sui::vec_set::{Self, VecSet};

  struct WhitelistKey has copy, store, drop {}

  public fun add_whitelist_address(uid: &mut UID, address: address) {
    if (df::exists_(uid, WhitelistKey {})) {
      let whitelist = df::borrow_mut<WhitelistKey, VecSet<address>>(uid, WhitelistKey {});
      vec_set::insert(whitelist, address);
    } else {
      let whitelist = vec_set::singleton(address);
      df::add(uid, WhitelistKey {}, whitelist);
    }
  }

  public fun in_whitelist(uid: &UID, address: address): bool {
    if (df::exists_(uid, WhitelistKey {})) {
      let whitelist = df::borrow<WhitelistKey, VecSet<address>>(uid, WhitelistKey {});
      vec_set::contains(whitelist, &address)
    } else {
      false
    }
  }
}
