module switchboard::aggregator;

use std::u64;
use std::string::String;
use sui::vec_set;
use sui::clock::Clock;
use switchboard::decimal::{Self, Decimal};

const MAX_RESULTS: u64 = 16;
const VERSION: u8 = 1;

public struct CurrentResult has drop, store {
    result: Decimal,
    timestamp_ms: u64,
    min_timestamp_ms: u64,
    max_timestamp_ms: u64,
    min_result: Decimal,
    max_result: Decimal,
    stdev: Decimal,
    range: Decimal,
    mean: Decimal,
}

public struct Update has copy, drop, store {
    result: Decimal,
    timestamp_ms: u64,
    oracle: ID,
}

public struct UpdateState has store {
    results: vector<Update>,
    curr_idx: u64,
}

public struct Aggregator has key {
    id: UID,

    // The queue this aggregator is associated with
    queue: ID,

    // The time this aggregator was created
    created_at_ms: u64,

    // -- Configs --

    // The name of the aggregator
    name: String,

    // The address of the authority that created this aggregator
    authority: address,

    // The hash of the feed this aggregator is associated with
    feed_hash: vector<u8>,

    // The minimum number of updates to consider the result valid
    min_sample_size: u64,

    // The maximum number of samples to consider the an update valid
    max_staleness_seconds: u64,

    // The maximum variance between jobs required for a result to be computed
    max_variance: u64,  

    // Minimum number of job successes required to compute a valid update
    min_responses: u32,


    // -- State --

    // The current result of the aggregator
    current_result: CurrentResult,

    // The state of the updates
    update_state: UpdateState,

    // version
    version: u8,
}

// -- Utility Functions --
public fun has_authority(aggregator: &Aggregator, ctx: &mut TxContext): bool {
    aggregator.authority == ctx.sender()
}

// -- Aggregator Accessors --

public fun id(aggregator: &Aggregator): ID {
    aggregator.id.to_inner()
}

public fun name(aggregator: &Aggregator): String {
    aggregator.name
}

public fun authority(aggregator: &Aggregator): address {
    aggregator.authority
}

public fun queue(aggregator: &Aggregator): ID {
    aggregator.queue
}

public fun created_at_ms(aggregator: &Aggregator): u64 {
    aggregator.created_at_ms
}

public fun feed_hash(aggregator: &Aggregator): vector<u8> {
    aggregator.feed_hash
}

public fun min_sample_size(aggregator: &Aggregator): u64 {
    aggregator.min_sample_size
}

public fun max_staleness_seconds(aggregator: &Aggregator): u64 {
    aggregator.max_staleness_seconds
}

public fun min_responses(aggregator: &Aggregator): u32 {
    aggregator.min_responses
}

public fun max_variance(aggregator: &Aggregator): u64 {
    aggregator.max_variance
}

public fun current_result(aggregator: &Aggregator): &CurrentResult {
    &aggregator.current_result
}

public fun version(aggregator: &Aggregator): u8 {
    aggregator.version
}

// -- CurrentResult Accessors --

public fun result(current_result: &CurrentResult): &Decimal {
    &current_result.result
}

public fun min_timestamp_ms(current_result: &CurrentResult): u64 {
    current_result.min_timestamp_ms
}

public fun max_timestamp_ms(current_result: &CurrentResult): u64 {
    current_result.max_timestamp_ms
}

public fun min_result(current_result: &CurrentResult): &Decimal {
    &current_result.min_result
}

public fun max_result(current_result: &CurrentResult): &Decimal {
    &current_result.max_result
}

public fun stdev(current_result: &CurrentResult): &Decimal {
    &current_result.stdev
}

public fun range(current_result: &CurrentResult): &Decimal {
    &current_result.range
}

public fun mean(current_result: &CurrentResult): &Decimal {
    &current_result.mean
}

public fun timestamp_ms(current_result: &CurrentResult): u64 {
    current_result.timestamp_ms
}

// -- Mutators --

public(package) fun new(
    queue: ID,
    name: String,
    authority: address,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    created_at_ms: u64,
    ctx: &mut TxContext,
): ID {

    let id = object::new(ctx);
    let aggregator_id = *(id.as_inner());
    let aggregator = Aggregator {
        id,
        queue,
        name,
        authority,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
        created_at_ms,
        current_result: CurrentResult {
            result: decimal::zero(),
            min_timestamp_ms: 0,
            max_timestamp_ms: 0,
            min_result: decimal::zero(),
            max_result: decimal::zero(),
            stdev: decimal::zero(),
            range: decimal::zero(),
            mean: decimal::zero(),
            timestamp_ms: 0,
        },
        update_state: UpdateState {
            results: vector::empty(),
            curr_idx: 0,
        },
        version: VERSION,
    };
    transfer::share_object(aggregator);
    aggregator_id
}


public(package) fun set_authority(aggregator: &mut Aggregator, new_authority: address) {
    aggregator.authority = new_authority;
}

public(package) fun set_configs(
    aggregator: &mut Aggregator,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
) {
    aggregator.feed_hash = feed_hash;
    aggregator.min_sample_size = min_sample_size;
    aggregator.max_staleness_seconds = max_staleness_seconds;
    aggregator.max_variance = max_variance;
    aggregator.min_responses = min_responses;
}

// add result
public(package) fun add_result(
    aggregator: &mut Aggregator,
    result: Decimal,
    timestamp_ms: u64,
    oracle: ID,
    clock: &Clock,
) {
    let now_ms = clock.timestamp_ms();
    set_update(&mut aggregator.update_state, result, oracle, timestamp_ms);
    let mut current_result = compute_current_result(aggregator, now_ms);
    if (current_result.is_some()) {
        aggregator.current_result = current_result.extract();
        // todo: log the result
    };
}

// delete the aggregator
public(package) fun delete(aggregator: Aggregator) {
    let Aggregator {
        id,
        queue: _,
        name: _,
        authority: _,
        feed_hash: _,
        min_sample_size: _,
        max_staleness_seconds: _,
        max_variance: _,
        min_responses: _,
        created_at_ms: _,
        current_result: _,
        update_state,
        version: _,
    } = aggregator;

    let UpdateState {
        results: _,
        curr_idx: _,
    } = update_state;

    // destroy the id
    id.delete();
}


// add a new result to the aggregator
fun set_update(
    update_state: &mut UpdateState,
    result: Decimal,
    oracle: ID,
    timestamp_ms: u64,
) {

    // check if the result is valid
    let results = &mut update_state.results;
    let last_idx = update_state.curr_idx;
    let curr_idx = (last_idx + 1) % MAX_RESULTS;

    if (results.length() == 0) {
        results.push_back(Update {
            result,
            timestamp_ms,
            oracle,
        });
        return
    };

    // check if the result is valid
    if (results.length() > 0) {
        let last_result = &results[last_idx];
        if (timestamp_ms < last_result.timestamp_ms) {

            // todo: remove this assert
            assert!(false, timestamp_ms);
            return
        };
    };
    
    // add the result at the current index
    if (results.length() < MAX_RESULTS) {
        results.push_back(Update {
            result,
            timestamp_ms,
            oracle,
        });
    } 
    // else update the existing result
    else {
        let existing_result = results.borrow_mut(curr_idx);
        existing_result.result = result;
        existing_result.timestamp_ms = timestamp_ms;
        existing_result.oracle = oracle;
    };

    // update the current index
    update_state.curr_idx = curr_idx;
}

// Compute the current result
fun compute_current_result(aggregator: &Aggregator, now_ms: u64): Option<CurrentResult> {
    let update_state = &aggregator.update_state;
    let updates = &update_state.results;
    let mut update_indices = update_state.valid_update_indices(aggregator.max_staleness_seconds * 1000, now_ms);

    // if there are not enough valid updates, return
    if (update_indices.length() < aggregator.min_sample_size) {
        return option::none()
    };

    // if there's only 1 index, return the result
    if (update_indices.length() == 1) {
        let (result, timestamp_ms) = update_state.median_result(&mut update_indices);
        return option::some(CurrentResult {
            min_timestamp_ms: updates[update_indices[0]].timestamp_ms,
            max_timestamp_ms: updates[update_indices[0]].timestamp_ms,
            min_result: result,
            max_result: result,
            range: decimal::zero(),
            result,
            stdev: decimal::zero(),
            mean: result,
            timestamp_ms,
        })
    };

    let mut sum: u128 = 0;
    let mut min_result = decimal::max_value();
    let mut max_result = decimal::zero();
    let mut min_timestamp_ms = u64::max_value!();
    let mut max_timestamp_ms = 0;
    let mut mean: u128 = 0;
    let mut mean_neg: bool = false;
    let mut m2: u256 = 0;
    let mut m2_neg: bool = false;
    let mut count: u128 = 0;

    vector::do_ref!(&update_indices, |idx| {
        let update = &updates[*idx];
        let value = update.result.value();
        let value_neg = update.result.neg();
        count = count + 1;

        // Welford's online algorithm
        let (delta, delta_neg) = sub_i128(value, value_neg, mean, mean_neg);
        (mean, mean_neg) = add_i128(mean, mean_neg, delta / count, delta_neg);
        let (delta2, delta2_neg) = sub_i128(value, value_neg, mean, mean_neg);

        (m2, m2_neg) = add_i256(m2, m2_neg, (delta as u256) * (delta2 as u256), delta_neg != delta2_neg);

        sum = sum + value;
        min_result = decimal::min(&min_result, &update.result);
        max_result = decimal::max(&max_result, &update.result);
        min_timestamp_ms = u64::min(min_timestamp_ms, update.timestamp_ms);
        max_timestamp_ms = u64::max(max_timestamp_ms, update.timestamp_ms);
    });

    let variance = m2 / ((count - 1) as u256); 
    let stdev = sqrt(variance);
    let range = max_result.sub(&min_result);
    let (result, timestamp_ms) = update_state.median_result(&mut update_indices);
    
    // update the current result
    option::some(CurrentResult {
        min_timestamp_ms,
        max_timestamp_ms,
        min_result,
        max_result,
        range,
        result,
        stdev: decimal::new(stdev, false),
        mean: decimal::new(mean, false),
        timestamp_ms,
    })
}

// basically a translation of eip7512
// todo: check if this is practically cheaper than babylonian
public fun sqrt(x: u256): u128 {
    if (x == 0) {
        return 0
    };

    let mut xx: u256 = x;
    let mut r: u256 = 1;

    if (xx >= 0x100000000000000000000000000000000) {
        xx = xx >> 128;
        r = r << 64;
    };
    if (xx >= 0x10000000000000000) {
        xx = xx >> 64;
        r = r << 32;
    };
    if (xx >= 0x100000000) {
        xx = xx >> 32;
        r = r << 16;
    };
    if (xx >= 0x10000) {
        xx = xx >> 16;
        r = r << 8;
    };
    if (xx >= 0x100) {
        xx = xx >> 8;
        r = r << 4;
    };
    if (xx >= 0x10) {
        xx = xx >> 4;
        r = r << 2;
    };
    if (xx >= 0x8) {
        r = r << 1;
    };

    // Iteratively refine r
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;

    let r1: u256 = x / r;

    // Return the smaller of r or r1 as u128
    if (r < r1) {
        return (r as u128)
    } else {
        return (r1 as u128)
    }
}

fun add_i256(a: u256, a_neg: bool, b: u256, b_neg: bool): (u256, bool) {
    if (a_neg && b_neg) {
        return (a + b, true)
    } else if (!a_neg && b_neg) {
        if (a < b) {
            return (b - a, true)
        } else {
            return (a - b, false)
        }
    } else if (a_neg && !b_neg) {
        if (a < b) {
            return (b - a, false)
        } else {
            return (a - b, true)
        }
    } else {
        return (a + b, false)
    }
}


fun add_i128(a: u128, a_neg: bool, b: u128, b_neg: bool): (u128, bool) {
    if (a_neg && b_neg) {
        return (a + b, true)
    } else if (!a_neg && b_neg) {
        if (a < b) {
            return (b - a, true)
        } else {
            return (a - b, false)
        }
    } else if (a_neg && !b_neg) {
        if (a < b) {
            return (b - a, false)
        } else {
            return (a - b, true)
        }
    } else {
        return (a + b, false)
    }
}

fun sub_i128(a: u128, a_neg: bool, b: u128, b_neg: bool): (u128, bool) {
    add_i128(a, a_neg, b, !b_neg)
}

// select median or lower bound middle item if even (with quickselect)
// sort the update indices in place
fun median_result(update_state: &UpdateState, update_indices: &mut vector<u64>): (Decimal, u64) {
    let updates = &update_state.results;
    let n = update_indices.length();
    let mid = n / 2;
    let mut lo = 0;
    let mut hi = n - 1;

    while (lo < hi) {
        let pivot = update_indices[hi];
        let mut i = lo;
        let mut j = lo;

        while (j < hi) {
            if (updates[update_indices[j]].result.lt(&updates[pivot].result)) {
                update_indices.swap(i, j);
                i = i + 1;
            };
            j = j + 1;
        };

        update_indices.swap(i, hi);

        if (i == mid) {
            break
        } else if (i < mid) {
            lo = i + 1;
        } else {
            hi = i - 1;
        };
    };

    // return the median result
    (updates[update_indices[mid]].result, updates[update_indices[mid]].timestamp_ms)
}

// Get the indices of valid updates
// rules: 
// 1: Only 1 update per oracle
// 2: Only the most recent update per oracle
// 3: Only updates that are within the max staleness
fun valid_update_indices(update_state: &UpdateState, max_staleness_ms: u64, now_ms: u64): vector<u64> {
    let results = &update_state.results;
    let mut valid_updates = vector::empty<u64>();
    let mut seen_oracles = vec_set::empty<ID>();

    // loop backwards through the results
    let mut idx =  update_state.curr_idx;
    let mut remaining_max_iterations = u64::min(MAX_RESULTS, results.length());
    
    if (remaining_max_iterations == 0) {
        return valid_updates
    };

    loop {

        // if there are no remaining iterations, or the current element is stale, break
        if (remaining_max_iterations == 0 || (results[idx].timestamp_ms + max_staleness_ms) < now_ms) {
            break
        };

        let result = &results[idx];
        let oracle = result.oracle;
        

        if (!seen_oracles.contains(&oracle)) {
            seen_oracles.insert(oracle);
            valid_updates.push_back(idx);
        };

        // step backwards
        if (idx == 0) {
            idx = results.length() - 1;
        } else {
            idx = idx - 1;
        };

        remaining_max_iterations = remaining_max_iterations - 1;
    };

    valid_updates
}

#[test_only]
public fun set_current_value(
    aggregator: &mut Aggregator,
    result: Decimal,
    timestamp_ms: u64,
    min_timestamp_ms: u64,
    max_timestamp_ms: u64,
    min_result: Decimal,
    max_result: Decimal,
    stdev: Decimal, 
    range: Decimal,
    mean: Decimal,
) {
    aggregator.current_result = CurrentResult {
        result,
        timestamp_ms,
        min_timestamp_ms,
        max_timestamp_ms,
        min_result,
        max_result,
        stdev,
        range,
        mean,
    }
}


#[test_only]
public fun new_aggregator(
    queue: ID,
    name: String,
    authority: address,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    created_at_ms: u64,
    ctx: &mut TxContext,
): Aggregator {
    Aggregator {
        id: object::new(ctx),
        queue,
        name,
        authority,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
        created_at_ms,
        current_result: CurrentResult {
            result: decimal::zero(),
            min_timestamp_ms: 0,
            max_timestamp_ms: 0,
            min_result: decimal::zero(),
            max_result: decimal::zero(),
            stdev: decimal::zero(),
            range: decimal::zero(),
            mean: decimal::zero(),
            timestamp_ms: 0,
        },
        update_state: UpdateState {
            results: vector::empty(),
            curr_idx: 0,
        },
        version: VERSION,
    }
}

#[test]
fun test_aggregregator_accessors() {
    use sui::test_scenario;
    use std::string;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"test_aggregator"),
        owner,
        vector::empty(),
        10,
        1000,
        100,
        5,
        1000,
        ctx,
    );
    assert!(queue(&aggregator) == example_queue_id());
    assert!(name(&aggregator) == string::utf8(b"test_aggregator"));
    assert!(authority(&aggregator) == owner);
    assert!(feed_hash(&aggregator) == vector::empty());
    assert!(min_sample_size(&aggregator) == 10);
    assert!(max_staleness_seconds(&aggregator) == 1000);
    assert!(max_variance(&aggregator) == 100);
    assert!(min_responses(&aggregator) == 5);
    assert!(created_at_ms(&aggregator) == 1000);
    destroy_aggregator(aggregator);
    test_scenario::end(scenario);
}

#[test]
fun test_current_result_accessors() {
    use sui::test_scenario;
    use std::string;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"test_aggregator"),
        owner,
        vector::empty(),
        10,
        1000,
        100,
        5,
        1000,
        ctx,
    );

    let current_result = current_result(&aggregator);
    assert!(result(current_result) == decimal::zero());
    assert!(min_timestamp_ms(current_result) == 0);
    assert!(max_timestamp_ms(current_result) == 0);
    assert!(min_result(current_result) == decimal::zero());
    assert!(max_result(current_result) == decimal::zero());
    assert!(stdev(current_result) == decimal::zero());
    assert!(range(current_result) == decimal::zero());
    assert!(mean(current_result) == decimal::zero());

    // destroy the id
    destroy_aggregator(aggregator);
    test_scenario::end(scenario);
}

#[test_only]
fun destroy_aggregator(aggregator: Aggregator) {
    let Aggregator {
        id,
        queue: _,
        name: _,
        authority: _,
        feed_hash: _,
        min_sample_size: _,
        max_staleness_seconds: _,
        max_variance: _,
        min_responses: _,
        created_at_ms: _,
        current_result: _,
        update_state,
        version: _,
    } = aggregator;

    let UpdateState {
        results: _,
        curr_idx: _,
    } = update_state;

    // destroy the id
    object::delete(id);
}

#[test]
fun test_aggregator_updates() {
    use sui::test_scenario;
    use std::string;
    use sui::clock;
    use sui::test_utils;

    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let mut clock = clock::create_for_testing(ctx);

    let mut aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"test_aggregator"),
        owner,
        vector::empty(),
        3,
        1000000000000000,
        100000000000,
        5,
        1000,
        ctx,
    );

    let oracle1 = object::id_from_address(@0x1);
    let oracle2 = object::id_from_address(@0x2);
    let oracle3 = object::id_from_address(@0x3);
    let oracle4 = object::id_from_address(@0x4);
    let oracle5 = object::id_from_address(@0x5);
    let oracle6 = object::id_from_address(@0x6);
    let oracle7 = object::id_from_address(@0x7);
    let oracle8 = object::id_from_address(@0x8);
    let oracle9 = object::id_from_address(@0x9);
    let oracle10 = object::id_from_address(@0x10);
    let oracle11 = object::id_from_address(@0x11);
    let oracle12 = object::id_from_address(@0x12);
    let oracle13 = object::id_from_address(@0x13);
    let oracle14 = object::id_from_address(@0x14);
    let oracle15 = object::id_from_address(@0x15);
    let oracle16 = object::id_from_address(@0x16);
    let oracle17 = object::id_from_address(@0x17);
    let oracle18 = object::id_from_address(@0x18);


    // add 18 results
    let result1 = decimal::new(100000000000000000, false);
    let result2 = decimal::new(123456789000000000, false);
    // 
    let result3 = decimal::new(567891234000000000, false);
    let result4 = decimal::new(789123456000000000, false);
    let result5 = decimal::new(912345678000000000, false);
    let result6 = decimal::new(345678912000000000, false);
    let result7 = decimal::new(456789123000000000, false);
    let result8 = decimal::new(567891234000000000, false);
    let result9 = decimal::new(678912345000000000, false);
    let result10 = decimal::new(789123456000000000, false);
    let result11 = decimal::new(891234567000000000, false);
    let result12 = decimal::new(912345678000000000, false);
    let result13 = decimal::new(123456789000000000, false);
    let result14 = decimal::new(234567891000000000, false);
    let result15 = decimal::new(345678912000000000, false);
    let result16 = decimal::new(456789123000000000, false);
    let result17 = decimal::new(567891234000000000, false);
    let result18 = decimal::new(678912345000000000, false);

    clock::set_for_testing(&mut clock, 18000000);
    
    add_result(&mut aggregator, result1, 1000000, oracle1, &clock);
    add_result(&mut aggregator, result2, 2000000, oracle2, &clock);
    add_result(&mut aggregator, result3, 3000000, oracle3, &clock);
    add_result(&mut aggregator, result4, 4000000, oracle4, &clock);
    add_result(&mut aggregator, result5, 5000000, oracle5, &clock);
    add_result(&mut aggregator, result6, 6000000, oracle6, &clock);
    add_result(&mut aggregator, result7, 7000000, oracle7, &clock);
    add_result(&mut aggregator, result8, 8000000, oracle8, &clock);
    add_result(&mut aggregator, result9, 9000000, oracle9, &clock);
    add_result(&mut aggregator, result10, 10000000, oracle10, &clock);
    add_result(&mut aggregator, result11, 11000000, oracle11, &clock);
    add_result(&mut aggregator, result12, 12000000, oracle12, &clock);
    add_result(&mut aggregator, result13, 13000000, oracle13, &clock);
    add_result(&mut aggregator, result14, 14000000, oracle14, &clock);
    add_result(&mut aggregator, result15, 15000000, oracle15, &clock);
    add_result(&mut aggregator, result16, 16000000, oracle16, &clock);
    add_result(&mut aggregator, result17, 17000000, oracle17, &clock);
    add_result(&mut aggregator, result18, 18000000, oracle18, &clock);

    // 
    
    let mut current_result = aggregator.compute_current_result(18000001);
    assert!(current_result.is_some());
    let current_result = current_result.extract();
    let expected_mean = 582414498562500000;
    let expected_range = 788888889000000000;
    let expected_stdev = 244005876836960000;

    // tolerate stdev being off by 0.00000000000001 in this example
    let tolerated_precision_err = 10000;

    assert!(result(&current_result) == result3, result(&current_result).value() as u64);
    assert!(min_timestamp_ms(&current_result) == 3000000);
    assert!(max_timestamp_ms(&current_result) == 18000000);
    assert!(min_result(&current_result) == result13, min_result(&current_result).value() as u64);
    assert!(max_result(&current_result) == result12, max_result(&current_result).value() as u64);
    if ((stdev(&current_result).value() > expected_stdev - tolerated_precision_err && 
        stdev(&current_result).value() < expected_stdev + tolerated_precision_err) == false) {
        test_utils::print(b"stdev in this (failing) test is:");
        test_utils::print(*stdev(&current_result).value().to_string().as_bytes());
    };

    assert!(
        stdev(&current_result).value() > expected_stdev - tolerated_precision_err && 
        stdev(&current_result).value() < expected_stdev + tolerated_precision_err, 
        0
    );
    assert!(range(&current_result) == decimal::new(expected_range, false), range(&current_result).value() as u64);
    assert!(mean(&current_result) == decimal::new(expected_mean, false), mean(&current_result).value() as u64);

    // destroy the id
    destroy_aggregator(aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


#[test]
fun test_aggregator_updates_big() {
    use sui::test_scenario;
    use std::string;
    use sui::clock;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let mut clock = clock::create_for_testing(ctx);

    let mut aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"test_aggregator"),
        owner,
        vector::empty(),
        3,
        1000000000000000,
        100000000000,
        5,
        1000,
        ctx,
    );

    let oracle1 = object::id_from_address(@0x1);
    let oracle2 = object::id_from_address(@0x2);
    let oracle3 = object::id_from_address(@0x3);
    let oracle4 = object::id_from_address(@0x4);
    let oracle5 = object::id_from_address(@0x5);
    let oracle6 = object::id_from_address(@0x6);
    let oracle7 = object::id_from_address(@0x7);
    let oracle8 = object::id_from_address(@0x8);
    let oracle9 = object::id_from_address(@0x9);
    let oracle10 = object::id_from_address(@0x10);
    let oracle11 = object::id_from_address(@0x11);
    let oracle12 = object::id_from_address(@0x12);
    let oracle13 = object::id_from_address(@0x13);
    let oracle14 = object::id_from_address(@0x14);
    let oracle15 = object::id_from_address(@0x15);
    let oracle16 = object::id_from_address(@0x16);
    let oracle17 = object::id_from_address(@0x17);
    let oracle18 = object::id_from_address(@0x18);


    // add 18 results
    let result1 = decimal::new(1733365173000000000000000000, false);
    let result2 = decimal::new(1733365173000000000000000000, false);
    // 
    let result3 = decimal::new(1733365173000000000000000000, false);
    let result4 = decimal::new(1733365173000000000000000000, false);
    let result5 = decimal::new(1733365173000000000000000000, false);
    let result6 = decimal::new(1733365173000000000000000000, false);
    let result7 = decimal::new(1733365173000000000000000000, false);
    let result8 = decimal::new(1733365173000000000000000000, false);
    let result9 = decimal::new(1733365173000000000000000000, false);
    let result10 = decimal::new(1733365173000000000000000000, false);
    let result11 = decimal::new(1733365173000000000000000000, false);
    let result12 = decimal::new(1733365173000000000000000000, false);
    let result13 = decimal::new(1733365173000000000000000000, false);
    let result14 = decimal::new(1733365173000000000000000000, false);
    let result15 = decimal::new(1733365173000000000000000000, false);
    let result16 = decimal::new(1733365173000000000000000000, false);
    let result17 = decimal::new(1733365173000000000000000000, false);
    let result18 = decimal::new(1733365173000000000000000000, false);

    clock::set_for_testing(&mut clock, 18000000);
    
    add_result(&mut aggregator, result1, 1000000, oracle1, &clock);
    add_result(&mut aggregator, result2, 2000000, oracle2, &clock);
    add_result(&mut aggregator, result3, 3000000, oracle3, &clock);
    add_result(&mut aggregator, result4, 4000000, oracle4, &clock);
    add_result(&mut aggregator, result5, 5000000, oracle5, &clock);
    add_result(&mut aggregator, result6, 6000000, oracle6, &clock);
    add_result(&mut aggregator, result7, 7000000, oracle7, &clock);
    add_result(&mut aggregator, result8, 8000000, oracle8, &clock);
    add_result(&mut aggregator, result9, 9000000, oracle9, &clock);
    add_result(&mut aggregator, result10, 10000000, oracle10, &clock);
    add_result(&mut aggregator, result11, 11000000, oracle11, &clock);
    add_result(&mut aggregator, result12, 12000000, oracle12, &clock);
    add_result(&mut aggregator, result13, 13000000, oracle13, &clock);
    add_result(&mut aggregator, result14, 14000000, oracle14, &clock);
    add_result(&mut aggregator, result15, 15000000, oracle15, &clock);
    add_result(&mut aggregator, result16, 16000000, oracle16, &clock);
    add_result(&mut aggregator, result17, 17000000, oracle17, &clock);
    add_result(&mut aggregator, result18, 18000000, oracle18, &clock);

    let current_result = aggregator.compute_current_result(18000001);
    assert!(current_result.is_some());
    destroy_aggregator(aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_aggregator_updates_real() {
    use sui::test_scenario;
    use std::string;
    use sui::clock;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let mut clock = clock::create_for_testing(ctx);

    let mut aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"Unix Timestamp"),
        owner,
        vector::empty(),
        1,
        100,
        100000000000,
        5,
        1000,
        ctx,
    );


    let oracle1 = object::id_from_address(@0x1);
    let oracle2 = object::id_from_address(@0x2);
    let oracle3 = object::id_from_address(@0x3);

    let result1 = decimal::new(17333649660000012345000000000000000000, false);
    let result2 = decimal::new(17333651530000012345000000000000000000, false);
    let result3 = decimal::new(17333651730000012345000000000000000000, false);

    let timestamp1 = 1733364966000;
    let timestamp2 = 1733365153000;
    let timestamp3 = 1733365173000;

    // create a vector of type Update with each of the results
    let mut updates = vector::empty();
    updates.push_back(Update {
        result: result1,
        timestamp_ms: timestamp1,
        oracle: oracle1,
    });
    updates.push_back(Update {
        result: result2,
        timestamp_ms: timestamp2,
        oracle: oracle2,
    });
    updates.push_back(Update {
        result: result3,
        timestamp_ms: timestamp3,
        oracle: oracle3,
    });


    aggregator.update_state.results = updates;
    aggregator.update_state.curr_idx = 2;


    clock::set_for_testing(&mut clock, 1733365173000);

    let result4 = decimal::new(17333651730000012345000000000000000000, false);
    let oracle4 = object::id_from_address(@0x4);
    let timestamp4 = 1733365173000;

    // add the result
    add_result(&mut aggregator, result4, timestamp4, oracle4, &clock);
    let current_result = aggregator.compute_current_result(18000001);
    assert!(current_result.is_some());

    // wrap up the test
    destroy_aggregator(aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_aggregator_updates_single() {
    use sui::test_scenario;
    use std::string;
    use sui::clock;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();
    let mut clock = clock::create_for_testing(ctx);

    let mut aggregator = new_aggregator(
        example_queue_id(),
        string::utf8(b"test_aggregator"),
        owner,
        vector::empty(),
        1,
        1000000000000000,
        100000000000,
        5,
        1000,
        ctx,
    );

    let oracle1 = object::id_from_address(@0x1);
    let oracle2 = object::id_from_address(@0x2);
    let oracle3 = object::id_from_address(@0x3);
    let oracle4 = object::id_from_address(@0x4);
    let oracle5 = object::id_from_address(@0x5);
    let oracle6 = object::id_from_address(@0x6);
    let oracle7 = object::id_from_address(@0x7);
    let oracle8 = object::id_from_address(@0x8);
    let oracle9 = object::id_from_address(@0x9);
    let oracle10 = object::id_from_address(@0x10);
    let oracle11 = object::id_from_address(@0x11);
    let oracle12 = object::id_from_address(@0x12);
    let oracle13 = object::id_from_address(@0x13);
    let oracle14 = object::id_from_address(@0x14);
    let oracle15 = object::id_from_address(@0x15);
    let oracle16 = object::id_from_address(@0x16);
    let oracle17 = object::id_from_address(@0x17);
    let oracle18 = object::id_from_address(@0x18);


    // add 18 results
    let result1 = decimal::new(68384040000000000000000, false);
    let result2 = decimal::new(68384040000000000000000, false);
    // 
    let result3 = decimal::new(68384040000000000000000, false);
    let result4 = decimal::new(68384040000000000000000, false);
    let result5 = decimal::new(68384040000000000000000, false);
    let result6 = decimal::new(68384040000000000000000, false);
    let result7 = decimal::new(68384040000000000000000, false);
    let result8 = decimal::new(68384040000000000000000, false);
    let result9 = decimal::new(68384040000000000000000, false);
    let result10 = decimal::new(68384040000000000000000, false);
    let result11 = decimal::new(68384040000000000000000, false);
    let result12 = decimal::new(68384040000000000000000, false);
    let result13 = decimal::new(68384040000000000000000, false);
    let result14 = decimal::new(68384040000000000000000, false);
    let result15 = decimal::new(68384040000000000000000, false);
    let result16 = decimal::new(68384040000000000000000, false);
    let result17 = decimal::new(68384040000000000000000, false);
    let result18 = decimal::new(68384040000000000000000, false);

    clock::set_for_testing(&mut clock, 18000000);
    
    add_result(&mut aggregator, result1, 1000000, oracle1, &clock);
    add_result(&mut aggregator, result2, 2000000, oracle2, &clock);
    add_result(&mut aggregator, result3, 3000000, oracle3, &clock);
    add_result(&mut aggregator, result4, 4000000, oracle4, &clock);
    add_result(&mut aggregator, result5, 5000000, oracle5, &clock);
    add_result(&mut aggregator, result6, 6000000, oracle6, &clock);
    add_result(&mut aggregator, result7, 7000000, oracle7, &clock);
    add_result(&mut aggregator, result8, 8000000, oracle8, &clock);
    add_result(&mut aggregator, result9, 9000000, oracle9, &clock);
    add_result(&mut aggregator, result10, 10000000, oracle10, &clock);
    add_result(&mut aggregator, result11, 11000000, oracle11, &clock);
    add_result(&mut aggregator, result12, 12000000, oracle12, &clock);
    add_result(&mut aggregator, result13, 13000000, oracle13, &clock);
    add_result(&mut aggregator, result14, 14000000, oracle14, &clock);
    add_result(&mut aggregator, result15, 15000000, oracle15, &clock);
    add_result(&mut aggregator, result16, 16000000, oracle16, &clock);
    add_result(&mut aggregator, result17, 17000000, oracle17, &clock);
    add_result(&mut aggregator, result18, 18000000, oracle18, &clock);

    let current_result = aggregator.compute_current_result(18000001);
    assert!(current_result.is_some());
    destroy_aggregator(aggregator);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test_only]
public fun example_queue_id(): ID {
    object::id_from_address(@0x1)
}


