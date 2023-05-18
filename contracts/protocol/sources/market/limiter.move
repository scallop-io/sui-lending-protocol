module protocol::limiter {
  use std::vector;
  use x::wit_table::{Self, WitTable};
  use sui::tx_context::TxContext;
  use std::type_name::TypeName;

  const EOutflowReachedLimit: u64 = 0x10000;

  friend protocol::market;

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

  public(friend) fun init_table(ctx: &mut TxContext): WitTable<Limiters, TypeName, Limiter> {
    wit_table::new(Limiters {}, true, ctx)
  }

  public(friend) fun add_limiter(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    outflow_limit: u64,
    outflow_cycle_duration: u32,
    outflow_segment_duration: u32,
  ) {
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
      outflow_limit: outflow_limit,
      outflow_cycle_duration: outflow_cycle_duration,
      outflow_segment_duration: outflow_segment_duration,
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

  public(friend) fun update_outflow_limit_params(
    table: &mut WitTable<Limiters, TypeName, Limiter>,
    key: TypeName,
    new_limit: u64,
  ) {
    let limiter = wit_table::borrow_mut(Limiters {}, table, key);
    limiter.outflow_limit = new_limit;
  }

  /// updating outflow segment params will resets the segments values
  public(friend) fun update_outflow_segment_params(
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
    assert!(curr_outflow + value <= limiter.outflow_limit, EOutflowReachedLimit);

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

  #[test, expected_failure(abort_code = EOutflowReachedLimit)]
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