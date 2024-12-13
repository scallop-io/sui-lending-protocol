module protocol::error {

  // whitelist
  public fun whitelist_error(): u64 { 0x0000101 }

  // version
  public fun version_mismatch_error(): u64 { 0x0000201 }

  // obligation
  public fun invalid_obligation_error(): u64 { 0x0000301 }
  public fun obligation_locked(): u64 { 0x0000302 }
  public fun obligation_unlock_with_wrong_key(): u64 { 0x0000303 }
  public fun obligation_already_locked(): u64 { 0x0000304 }
  public fun obligation_access_lock_key_not_in_store(): u64 { 0x0000305 }
  public fun obligation_access_reward_key_not_in_store(): u64 { 0x0000306 }
  public fun obligation_access_store_key_exists(): u64 { 0x0000307 }
  public fun obligation_access_store_key_not_found(): u64 { 0x0000308 }
  public fun obligation_cant_forcely_unlocked(): u64 { 0x0000309 }

  // oracle
  public fun oracle_stale_price_error(): u64 { 0x0000401 }
  public fun oracle_price_not_found_error(): u64 { 0x0000402 }
  public fun oracle_zero_price_error(): u64 { 0x0000403 }

  // borrow
  public fun borrow_too_much_error(): u64 { 0x0000501 }
  public fun borrow_too_small_error(): u64 { 0x0000502 }
  public fun flash_loan_repay_not_enough_error(): u64 { 0x0000503 }
  public fun unable_to_borrow_a_collateral_coin(): u64 { 0x0000504 }
  public fun unable_to_borrow_other_coin_with_isolated_asset(): u64 { 0x0000505 }

  // liquidation
  public fun unable_to_liquidate_error(): u64 { 0x0000601 }

  // collateral error
  public fun max_collateral_reached_error(): u64 { 0x0000701 }
  public fun invalid_collateral_type_error(): u64 { 0x0000702 }
  public fun withdraw_collateral_too_much_error(): u64 { 0x0000703 }
  public fun unable_to_deposit_a_borrowed_coin(): u64 { 0x0000704 }

  // market coin error
  public fun mint_market_coin_too_small_error(): u64 { 0x0000801 }
  public fun redeem_market_coin_too_small_error(): u64 { 0x0000802 }

  // admin
  public fun interest_model_type_not_match_error(): u64 { 0x0000901 }
  public fun risk_model_type_not_match_error(): u64 { 0x0000902 }
  public fun invalid_params_error(): u64 { 0x0000903 }

  // misc
  public fun outflow_reach_limit_error(): u64 { 0x0001001 }

  // flashloan
  public fun flash_loan_not_paid_enough(): u64 { 0x0011001 }

  // asset not active errors
  public fun base_asset_not_active_error(): u64 { 0x0012001 }
  public fun collateral_not_active_error(): u64 { 0x0012002 }

  // risk model & interest model errors
  public fun risk_model_param_error(): u64 { 0x0013001 }
  public fun interest_model_param_error(): u64 { 0x0013002 }

  // pool liquidity errors
  public fun pool_liquidity_not_enough_error(): u64 { 0x0014001 }
  public fun supply_limit_reached(): u64 { 0x0014002 }
  public fun collateral_not_enough(): u64 { 0x0014003 }
  public fun reserve_not_enough_error(): u64 { 0x0014004 }
  public fun borrow_limit_reached_error(): u64 { 0x0014005 }

  // repay
  public fun zero_repay_amount_error(): u64 { 0x0015001 }
}
