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
    v.value = v.value + 1;
  }
  public fun is_current_version(v: &Version): bool {
    v.value == current_version()
  }
  public fun assert_current_version(v: &Version) {
    assert!(is_current_version(v), error::version_mismatch_error());
  }

  #[test_only]
  use sui::test_scenario;

  #[test]
  fun version_test() {
    let admin = @0x1;
    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    init(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let version = test_scenario::take_shared<Version>(scenario);
    let version_cap = test_scenario::take_from_address<VersionCap>(scenario, admin);

    assert_current_version(&version);
    assert!(value(&version) == current_version(), 0);

    upgrade(&mut version, &version_cap);
    assert!(!is_current_version(&version), 0);
    assert!(value(&version) == current_version() + 1, 0);

    test_scenario::return_to_address(admin, version_cap);
    test_scenario::return_shared(version);
    test_scenario::end(scenario_value);
  }

  #[test_only]
  public fun create_for_testing(ctx: &mut TxContext): Version {
    Version {
      id: object::new(ctx),
      value: current_version(),
    }
  }

  #[test_only]
  public fun create_cap_for_testing(ctx: &mut TxContext): VersionCap {
    VersionCap {
      id: object::new(ctx),
    }
  }  

  #[test_only]
  public fun destroy_for_testing(version: Version) {
    let Version { id, value: _ } = version;
    object::delete(id);
  }
}
