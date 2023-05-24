module protocol::error {

  public fun whitelist_error(): u64 { 0x0000400 }

  public fun oracle_stale_price_error(): u64 { 0x0000401 }
  public fun oracle_price_not_found_error(): u64 { 0x0000402 }
}
