module protocol::error {

  // whitelist
  public fun whitelist_error(): u64 { 0x0000101 }

  // version
  public fun version_mismatch_error(): u64 { 0x0000201 }

  // obligation
  public fun invalid_obligation_error(): u64 { 0x0000301 }

  // oracle
  public fun oracle_stale_price_error(): u64 { 0x0000401 }
  public fun oracle_price_not_found_error(): u64 { 0x0000402 }

  // borrow
  public fun borrow_too_much_error(): u64 { 0x0000501 }
  public fun borrow_too_small_error(): u64 { 0x0000502 }
  public fun flash_loan_repay_not_enough_error(): u64 { 0x0000503 }

  // liquidation
  public fun unable_to_liquidate_error(): u64 { 0x0000601 }

  // deposit collateral
  public fun max_collateral_reached_error(): u64 { 0x0000701 }
  public fun invalid_collateral_type_error(): u64 { 0x0000702 }

  // withdraw collateral
  public fun withdraw_collateral_too_much_error(): u64 { 0x0000801 }

  // admin
  public fun interest_model_type_not_match_error(): u64 { 0x0000901 }
  public fun risk_model_type_not_match_error(): u64 { 0x0000902 }

  // misc
  public fun outflow_reach_limit_error(): u64 { 0x0001001 }
}
