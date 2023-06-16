module protocol::limiter {
  use std::vector;
  use std::type_name::{Self, TypeName};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::error;
  use x::one_time_lock_value::{Self, OneTimeLockValue};
  use x::wit_table::{Self, WitTable};

  friend protocol::market;
  friend protocol::app;

  struct Limiter has store, drop {
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    /// how long is one segment in seconds
    outflow_segment_duration: u32,
    outflow_segments: vector<Segment>,
  }

  struct Limiters has drop {}

  struct Segment has store, drop {
    index: u64,
    value: u64
  }

  struct LimiterUpdateLimitChangeCreatedEvent has copy, drop {
    changes: LimiterUpdateLimitChange,
    current_epoch: u64,
    delay_epoches: u64,
    effective_epoches: u64
  }

  struct LimiterUpdateParamsChangeCreatedEvent has copy, drop {
    changes: LimiterUpdateParamsChange,
    current_epoch: u64,
    delay_epoches: u64,
    effective_epoches: u64
  }

  struct LimiterLimitChangeAppliedEvent has copy, drop {
    changes: LimiterUpdateLimitChange,
    current_epoch: u64,
  }

  struct LimiterParamsChangeAppliedEvent has copy, drop {
    changes: LimiterUpdateParamsChange,
    current_epoch: u64,
  }

  const LimiterUpdateChangeEffectiveEpoches: u64 = 7;

  struct LimiterUpdateLimitChange has copy, store, drop {
    coin_type: TypeName,
    outflow_limit: u64,
  }

  struct LimiterUpdateParamsChange has copy, store, drop {
    coin_type: TypeName,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  }

  /// update the params of limiter, the params contains how it calculated
  /// this changes will resets the calculation at the time it applied
  public(friend) fun create_limiter_params_change<T>(
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<LimiterUpdateParamsChange> {
    let changes = LimiterUpdateParamsChange {
      coin_type: type_name::get<T>(),
      outflow_cycle_duration,
      outflow_segment_duration,
    };
    emit(LimiterUpdateParamsChangeCreatedEvent {
      changes,
      current_epoch: tx_context::epoch(ctx),
      delay_epoches: change_delay,
      effective_epoches: tx_context::epoch(ctx) + change_delay
    });
    one_time_lock_value::new(changes, change_delay, LimiterUpdateChangeEffectiveEpoches, ctx)
  }

  /// update the limit of the limiter without resets current calculation
  /// NOTE: in most of the cases, we only need to update the limit
  public(friend) fun create_limiter_limit_change<T>(
    outflow_limit: u64,
    change_delay: u64,
    ctx: &mut TxContext,
  ): OneTimeLockValue<LimiterUpdateLimitChange> {
    let changes = LimiterUpdateLimitChange {
      coin_type: type_name::get<T>(),
      outflow_limit,
    };
    emit(LimiterUpdateLimitChangeCreatedEvent {
      changes,
      current_epoch: tx_context::epoch(ctx),
      delay_epoches: change_delay,
      effective_epoches: tx_context::epoch(ctx) + change_delay
    });
    one_time_lock_value::new(changes, change_delay, LimiterUpdateChangeEffectiveEpoches, ctx)
  }

  public(friend) fun apply_limiter_limit_change(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    changes: OneTimeLockValue<LimiterUpdateLimitChange>,
    ctx: &mut TxContext,
  ) {
    let params_change = one_time_lock_value::get_value(changes, ctx);

    update_outflow_limit_params(
      table,
      params_change.coin_type,
      params_change.outflow_limit
    );

    emit(LimiterLimitChangeAppliedEvent {
      changes: params_change,
      current_epoch: tx_context::epoch(ctx)
    });
  }

  public(friend) fun apply_limiter_params_change(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    changes: OneTimeLockValue<LimiterUpdateParamsChange>,
    ctx: &mut TxContext,
  ) {
    let params_change = one_time_lock_value::get_value(changes, ctx);

    update_outflow_segment_params(
      table,
      params_change.coin_type,
      params_change.outflow_cycle_duration,
      params_change.outflow_segment_duration
    );

    emit(LimiterParamsChangeAppliedEvent {
      changes: params_change,
      current_epoch: tx_context::epoch(ctx)
    });
  }

  public(friend) fun init_table(ctx: &mut TxContext): WitTable<Limiters, TypeName, Limiter> {
    wit_table::new(Limiters {}, true, ctx)
  }

  public(friend) fun add_limiter<T>(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ) {
    let key = type_name::get<T>();
    wit_table::add(Limiters {}, table, key, new(
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
    ));
  }

  fun new(
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ): Limiter {
    Limiter {
      outflow_limit,
      outflow_cycle_duration,
      outflow_segment_duration,
      outflow_segments: build_segments(
        outflow_cycle_duration,
        outflow_segment_duration,
      ),
    }
  }

  fun build_segments(
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ): vector<Segment> {
    let vec_segments = vector::empty();

    let (i, len) = (0, outflow_cycle_duration / outflow_segment_duration);
    while (i < len) {
      vector::push_back(&mut vec_segments, Segment {
        index: (i as u64),
        value: 0,
      });

      i = i + 1;
    };

    vec_segments
  }

  fun update_outflow_limit_params(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    new_limit: u64,
  ) {
    let limiter = wit_table::borrow_mut(Limiters {}, table, key);
    limiter.outflow_limit = new_limit;
  }

  /// updating outflow segment params will resets the segments values
  fun update_outflow_segment_params(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    cycle_duration: u32,
    segment_duration: u32,
  ) {
    let limiter = wit_table::borrow_mut(Limiters {}, table, key);

    limiter.outflow_segment_duration = segment_duration;
    limiter.outflow_cycle_duration = cycle_duration;
    limiter.outflow_segments = build_segments(
      cycle_duration,
      segment_duration,
    );
  }

  /// add_outflow will add the value of the outflow to the current segment
  /// but before adding it, there will be a check
  /// to validate that the outflow doesn't over the limit
  public(friend) fun add_outflow(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    now: u64,
    value: u64,
  ) {
    let curr_outflow = count_current_outflow(table, key, now);
    let limiter = wit_table::borrow_mut(Limiters {}, table, key);
    assert!(curr_outflow + value <= limiter.outflow_limit, error::outflow_reach_limit_error());

    let timestamp_index = now / (limiter.outflow_segment_duration as u64);
    let curr_index = timestamp_index % vector::length(&limiter.outflow_segments);
    let segment = vector::borrow_mut<Segment>(&mut limiter.outflow_segments, curr_index);
    if (segment.index != timestamp_index) {
      segment.index = timestamp_index;
      segment.value = 0;
    };
    segment.value = segment.value + value;
  }

  /// reducing the outflow value of current segment
  /// that's mean the sum of all segments in one cycle is also reduced
  /// NOTE: keep in mind that reducing a HUGE number of outflow
  /// of current segment doesn't affect the total value of outflow in a cycle
  public(friend) fun reduce_outflow(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    now: u64,
    reduced_value: u64,
  ) {
    let limiter = wit_table::borrow_mut(Limiters {}, table, key);

    let timestamp_index = now / (limiter.outflow_segment_duration as u64);
    let curr_index = timestamp_index % vector::length(&limiter.outflow_segments);
    let segment = vector::borrow_mut<Segment>(&mut limiter.outflow_segments, curr_index);
    if (segment.index != timestamp_index) {
      segment.index = timestamp_index;
      segment.value = 0;
    };

    if (segment.value <= reduced_value) {
      segment.value = 0;
    } else {
      segment.value = segment.value - reduced_value;
    }
  }

  /// return the sum of segments in one cycle
  public fun count_current_outflow(
    table: &WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    now: u64,
  ): u64 {
    let limiter = wit_table::borrow(table, key);

    let curr_outflow: u64 = 0;
    let timestamp_index = now / (limiter.outflow_segment_duration as u64);

    let (i, len) = (0, vector::length(&limiter.outflow_segments));
    while (i < len) {
      let segment = vector::borrow<Segment>(&limiter.outflow_segments, i);
      if ((len > timestamp_index) || (segment.index >= (timestamp_index - len + 1))) {
        curr_outflow = curr_outflow + segment.value;
      };
      i = i + 1;
    };

    curr_outflow
  }

  #[test_only]
  struct USDC has drop {}

  #[test_only]
  use sui::test_scenario;

  #[test_only]
  use std::type_name;

  #[test]
  fun outflow_limit_test() {
    let segment_duration: u64 = 60 * 30;
    let cycle_duration: u64 = 60 * 60 * 24;
    let segment_count = cycle_duration / segment_duration;

    let admin = @0xAA;
    let key = type_name::get<USDC>();

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let table = init_table(test_scenario::ctx(scenario));
    add_limiter(
      &mut table,
      key,
      segment_count * 100,
      (cycle_duration as u32),
      (segment_duration as u32),
    );

    let mock_timestamp = 100;

    let i = 0;
    while (i < segment_count) {
      mock_timestamp = mock_timestamp + segment_duration;
      add_outflow(&mut table, key, mock_timestamp, 100);
      i = i + 1;
    };

    // updating the timestamp here clearing the very first segment that we filled last time
    // hence the outflow limiter wouldn't throw an error because it satisfy the limit
    mock_timestamp = mock_timestamp + segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 100);
    reduce_outflow(&mut table, key, mock_timestamp, 100);
    add_outflow(&mut table, key, mock_timestamp, 100);

    wit_table::drop(Limiters {}, table);
    test_scenario::end(scenario_value);
  }

  #[test]
  fun update_outflow_params_test() {
    let segment_duration: u64 = 60 * 30;
    let cycle_duration: u64 = 60 * 60 * 24;

    let admin = @0xAA;
    let key = type_name::get<USDC>();

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let table = init_table(test_scenario::ctx(scenario));
    add_limiter(
      &mut table,
      key,
      10000,
      (cycle_duration as u32),
      (segment_duration as u32),
    );

    let mock_timestamp = 1000;

    add_outflow(&mut table, key, mock_timestamp, 5000);
    mock_timestamp = mock_timestamp + segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 3000);

    let new_cycle_duration: u64 = 60 * 60 * 24;
    let new_segment_duration: u64 = 60;
    // updating outflow segment params will resets segment params
    update_outflow_segment_params(&mut table, key, (new_cycle_duration as u32), (new_segment_duration as u32));

    mock_timestamp = mock_timestamp + new_segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 5000);
    mock_timestamp = mock_timestamp + new_segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 5000);

    update_outflow_limit_params(&mut table, key, 11000);
    mock_timestamp = mock_timestamp + new_segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 1000);

    wit_table::drop(Limiters {}, table);
    test_scenario::end(scenario_value);
  }

  // Error Outflow Reach Limit = 0x0001001 = 4097
  #[test, expected_failure(abort_code=4097, location=protocol::limiter)]
  fun outflow_limit_test_failed_reached_limit() {
    let segment_duration: u64 = 60 * 30;
    let cycle_duration: u64 = 60 * 60 * 24;
    let admin = @0xAA;
    let key = type_name::get<USDC>();

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let table = init_table(test_scenario::ctx(scenario));
    add_limiter(
      &mut table,
      key,
      10000,
      (cycle_duration as u32),
      (segment_duration as u32),
    );
    let mock_timestamp = 1000;

    add_outflow(&mut table, key, mock_timestamp, 5000);
    mock_timestamp = mock_timestamp + segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 3000);
    mock_timestamp = mock_timestamp + segment_duration;
    add_outflow(&mut table, key, mock_timestamp, 2001);

    wit_table::drop(Limiters {}, table);
    test_scenario::end(scenario_value);
  }
}