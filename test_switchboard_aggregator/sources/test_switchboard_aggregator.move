module test_switchboard_aggreator::test_switchboard_aggregator {
  use std::vector;
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use switchboard::aggregator::{Self, Aggregator};
  use switchboard::math;

  struct SecretKey has drop {}

  public fun init_aggregator(
    name: vector<u8>,
    value: u128,        // example the number 10 would be 10 * 10^dec (dec automatically scaled to 9)
    scale_factor: u8,   // example 9 would be 10^9, 10 = 1000000000
    negative: bool,     // example -10 would be true
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let aggregator = create_aggregator(name, clock, ctx);
    set_value(&mut aggregator, value, scale_factor, negative, clock, ctx);
    aggregator::share_aggregator(aggregator);
  }

  public fun create_aggregator(
    name: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
  ): Aggregator {
    aggregator::new(
      name, // name:
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
      clock::timestamp_ms(clock), // created_at:
      tx_context::sender(ctx), // authority, - this is the owner of the aggregator
      &SecretKey {}, // _friend_key: scopes the function to only by the package of aggregator creator (intenrnal)
      ctx,
    )
  }

  public fun set_value(
    aggregator: &mut Aggregator, // aggregator
    value: u128,        // example the number 10 would be 10 * 10^dec (dec automatically scaled to 9)
    scale_factor: u8,   // example 9 would be 10^9, 10 = 1000000000
    negative: bool,     // example -10 would be true
    clock: &Clock,           // timestamp (in seconds)
    ctx: &mut TxContext
  ) {

    // set the value of a test aggregator
    aggregator::push_update(
      aggregator,
      tx_context::sender(ctx),
      math::new(value, scale_factor, negative),
      clock::timestamp_ms(clock),
      &SecretKey {},
    );
  }
}
