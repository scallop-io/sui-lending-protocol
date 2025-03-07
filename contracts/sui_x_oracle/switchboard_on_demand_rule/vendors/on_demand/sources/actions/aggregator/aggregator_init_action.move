module switchboard::aggregator_init_action;

use std::string::String;
use sui::clock::Clock;
use sui::event;
use switchboard::aggregator;
use switchboard::queue::Queue;

const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidMinSampleSize: vector<u8> = b"Invalid min_sample_size";
#[error]
const EInvalidMaxVariance: vector<u8> = b"Invalid max_variance";
#[error]
const EInvalidFeedHash: vector<u8> = b"Invalid feed_hash";
#[error]
const EInvalidMinResponses: vector<u8> = b"Invalid min_responses";
#[error]
const EInvalidMaxStalenessSeconds: vector<u8> = b"Invalid max_staleness_seconds";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct AggregatorCreated has copy, drop {
    aggregator_id: ID,
    name: String,
}

public fun validate(
    queue: &Queue,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(min_sample_size > 0, EInvalidMinSampleSize);
    assert!(max_variance > 0, EInvalidMaxVariance);
    assert!(feed_hash.length() == 32, EInvalidFeedHash);
    assert!(min_responses > 0, EInvalidMinResponses);
    assert!(max_staleness_seconds > 0, EInvalidMaxStalenessSeconds);
}

fun actuate(
    authority: address,
    queue: &Queue,
    name: String,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    clock: &Clock,
    ctx: &mut TxContext,
) {

    // create aggregator & share it
    let aggregator_id = aggregator::new(
        queue.id(),
        name,
        authority,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
        clock.timestamp_ms(),
        ctx,
    );

    // emit event
    let aggregator_created = AggregatorCreated {
        aggregator_id,
        name,
    };
    event::emit(aggregator_created);
}

// initialize aggregator for user
public entry fun run(
    queue: &Queue,
    authority: address,
    name: String,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    clock: &Clock,
    ctx: &mut TxContext
) {   
    validate(
        queue,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
    );
    actuate(
        authority,
        queue,
        name,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
        clock,
        ctx
    );
}