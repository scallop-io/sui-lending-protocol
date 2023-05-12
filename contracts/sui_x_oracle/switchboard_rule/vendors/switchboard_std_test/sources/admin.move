module switchboard_std::admin {

  use std::vector;
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use switchboard_std::aggregator::{Self, Aggregator};
  use switchboard_std::math;

  struct SecretKey has drop {}

  public fun create_aggregator(ctx: &mut TxContext) {
    let aggregator = aggregator::new(
      b"test", // name:
      @0x0, // queue_addr:
      1, // batch_size:
      1, // min_oracle_results:
      1, // min_job_results:
      0, // min_update_delay_seconds:
      math::zero(), // variance_threshold:
      0, // force_report_period:
      false, // disable_crank:
      0, // history_limit:
      0, // read_charge:
      @0x0, // reward_escrow:
      vector::empty(), // read_whitelist:
      false, // limit_reads_to_whitelist:
      0, // created_at:
      tx_context::sender(ctx), // authority, - this is the owner of the aggregator
      &SecretKey {}, // _friend_key: scopes the function to only by the package of aggregator creator (intenrnal)
      ctx,
    );
    aggregator::share_aggregator(aggregator);
  }

  public fun set_value(
    aggregator: &mut Aggregator, // aggregator
    value: u64,        // example the number 10 would be 10 * 10^dec (dec automatically scaled to 9)
    scale_factor: u8,   // example 9 would be 10^9, 10 = 1000000000
    clock: &Clock,           // timestamp (in seconds)
    ctx: &mut TxContext
  ) {
    // set the value of a test aggregator
    let now = clock::timestamp_ms(clock) / 1000;
    aggregator::push_update(
      aggregator,
      tx_context::sender(ctx),
      math::new((value as u128), scale_factor, false),
      now,
      &SecretKey {},
    );
  }
}
