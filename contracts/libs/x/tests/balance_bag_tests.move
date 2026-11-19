#[test_only]
module x::balance_bag_tests {
  use sui::balance;
  use sui::sui::SUI;
  use sui::tx_context;
  use x::balance_bag;

  struct OTHER has drop {}

  #[test]
  fun remove_returns_whole_balance_and_deletes_entry_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);
    balance_bag::join(&mut bag, balance::create_for_testing<SUI>(100));

    let removed = balance_bag::remove<SUI>(&mut bag);
    assert!(balance::value(&removed) == 100, 0);
    assert!(!balance_bag::contains<SUI>(&bag), 1);

    balance::destroy_for_testing(removed);
    balance_bag::destroy_empty(bag);
  }

  #[test]
  fun remove_zero_balance_entry_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);

    let removed = balance_bag::remove<SUI>(&mut bag);
    assert!(balance::value(&removed) == 0, 0);
    assert!(!balance_bag::contains<SUI>(&bag), 1);

    balance::destroy_zero(removed);
    balance_bag::destroy_empty(bag);
  }

  #[test]
  fun remove_keeps_other_entries_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);
    balance_bag::init_balance<OTHER>(&mut bag);
    balance_bag::join(&mut bag, balance::create_for_testing<SUI>(100));
    balance_bag::join(&mut bag, balance::create_for_testing<OTHER>(7));

    let removed = balance_bag::remove<SUI>(&mut bag);
    assert!(balance::value(&removed) == 100, 0);
    assert!(!balance_bag::contains<SUI>(&bag), 1);
    assert!(balance_bag::contains<OTHER>(&bag), 2);
    assert!(balance_bag::value<OTHER>(&bag) == 7, 3);

    balance::destroy_for_testing(removed);
    balance::destroy_for_testing(balance_bag::remove<OTHER>(&mut bag));
    balance_bag::destroy_empty(bag);
  }

  #[test]
  fun init_again_after_remove_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);
    balance::destroy_zero(balance_bag::remove<SUI>(&mut bag));

    balance_bag::init_balance<SUI>(&mut bag);
    balance_bag::join(&mut bag, balance::create_for_testing<SUI>(5));
    assert!(balance_bag::value<SUI>(&bag) == 5, 0);

    balance::destroy_for_testing(balance_bag::remove<SUI>(&mut bag));
    balance_bag::destroy_empty(bag);
  }

  #[test]
  #[expected_failure(abort_code = 1, location = sui::dynamic_field)]
  fun remove_missing_entry_aborts_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    let removed = balance_bag::remove<SUI>(&mut bag);
    balance::destroy_zero(removed);
    balance_bag::destroy_empty(bag);
  }

  #[test]
  #[expected_failure(abort_code = 1, location = sui::dynamic_field)]
  fun split_zero_after_remove_aborts_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);
    balance::destroy_zero(balance_bag::remove<SUI>(&mut bag));

    let split = balance_bag::split<SUI>(&mut bag, 0);
    balance::destroy_zero(split);
    balance_bag::destroy_empty(bag);
  }

  #[test]
  #[expected_failure(abort_code = 1, location = sui::dynamic_field)]
  fun join_after_remove_aborts_test() {
    let ctx = tx_context::dummy();
    let bag = balance_bag::new(&mut ctx);
    balance_bag::init_balance<SUI>(&mut bag);
    balance::destroy_zero(balance_bag::remove<SUI>(&mut bag));

    balance_bag::join(&mut bag, balance::zero<SUI>());
    balance_bag::destroy_empty(bag);
  }
}
