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
  public fun oracle_zero_price_error(): u64 { 0x0000403 }

  // borrow
  public fun borrow_too_much_error(): u64 { 0x0000501 }
  public fun borrow_too_small_error(): u64 { 0x0000502 }
  public fun flash_loan_repay_not_enough_error(): u64 { 0x0000503 }

  // liquidation
  public fun unable_to_liquidate_error(): u64 { 0x0000601 }

  // collateral error
  public fun max_collateral_reached_error(): u64 { 0x0000701 }
  public fun invalid_collateral_type_error(): u64 { 0x0000702 }
  public fun withdraw_collateral_too_much_error(): u64 { 0x0000703 }

  // market coin error
  public fun mint_market_coin_too_small_error(): u64 { 0x0000801 }

  // admin
  public fun interest_model_type_not_match_error(): u64 { 0x0000901 }
  public fun risk_model_type_not_match_error(): u64 { 0x0000902 }

  // misc
  public fun outflow_reach_limit_error(): u64 { 0x0001001 }

  // flashloan
  public fun flash_loan_not_paid_enough(): u64 { 0x0011001 }

  // asset not active errors
  public fun base_asset_not_active_error(): u64 { 0x0012001 }
  public fun collateral_not_active_error(): u64 { 0x0012002 }

  // risk model & interest model errors
  public fun risk_model_param_error(): u64 { 0x0013001 }

  // pool liquidity errors
  public fun pool_liquidity_not_enough_error(): u64 { 0x0014001 }
}
