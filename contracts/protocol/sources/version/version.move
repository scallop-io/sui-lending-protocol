module protocol::version {

  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;

  use protocol::current_version::current_version;
  use protocol::error;

  struct Version has key, store {
    id: UID,
    value: u64,
  }

  struct VersionCap has key, store {
    id: UID
  }

  fun init(ctx: &mut TxContext) {
    let version = Version {
      id: object::new(ctx),
      value: current_version(),
    };
    let cap = VersionCap {
      id: object::new(ctx),
    };
    transfer::share_object(version);
    transfer::transfer(cap, tx_context::sender(ctx));
  }

  // ======= version control ==========
  public fun value(v: &Version): u64 { v.value }
  public fun upgrade(v: &mut Version, _: &VersionCap) {
    v.value = current_version() + 1;
  }
  public fun is_current_version(v: &Version): bool {
    v.value == current_version()
  }
  public fun assert_current_version(v: &Version) {
    assert!(is_current_version(v), error::version_mismatch_error());
  }

  #[test_only]
  public fun create_for_testing(ctx: &mut TxContext): Version {
    Version {
      id: object::new(ctx),
      value: current_version(),
    }
  }

  #[test_only]
  public fun destroy_for_testing(version: Version) {
    let Version { id, value: _ } = version;
    object::delete(id);
  }
}
