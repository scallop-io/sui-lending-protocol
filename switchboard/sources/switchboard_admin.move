module switchboard::switchboard_admin {
  use std::vector;
  use switchboard::aggregator::{Self, Aggregator};
  use switchboard::math;
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::object::ID;
  use sui::object;

  struct SecretKey has drop {}

  struct AggregatorHotPotato {
    aggr_id: ID,
  }

  public fun new_aggregator(name: vector<u8>, ctx: &mut TxContext): (Aggregator, AggregatorHotPotato) {
    let aggr = fake_aggregator(name, ctx);
    let aggr_id = object::id(&aggr);
    (aggr, AggregatorHotPotato { aggr_id })
  }

  public fun share_aggregator(aggr: Aggregator, aggr_hot_potato: AggregatorHotPotato) {
    let AggregatorHotPotato { aggr_id } = aggr_hot_potato;
    assert!(object::id(&aggr) == aggr_id, 0);
    aggregator::share_aggregator(aggr);
  }

  public entry fun update_price(
    aggregator: &mut Aggregator,
    value: u128,
    scale_factor: u8,
    negative: bool,
    clock: &Clock,
    ctx: &mut TxContext
  ) {
    let now = clock::timestamp_ms(clock);
    aggregator::push_update(
      aggregator,
      tx_context::sender(ctx),
      math::new(value, scale_factor, negative),
      now,
      &SecretKey {},
    );
  }

  fun fake_aggregator(name: vector<u8>, ctx: &mut TxContext): Aggregator {
    aggregator::new(
      name,
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
    )
  }
}
