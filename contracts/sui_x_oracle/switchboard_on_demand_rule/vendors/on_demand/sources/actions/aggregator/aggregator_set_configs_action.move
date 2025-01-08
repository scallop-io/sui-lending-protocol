module switchboard::aggregator_set_configs_action;

use sui::event;
use switchboard::aggregator::Aggregator;

const EXPECTED_AGGREGATOR_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
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
const EInvalidAggregatorVersion: vector<u8> = b"Invalid aggregator version";

public struct AggregatorConfigsUpdated has copy, drop {
    aggregator_id: ID,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
}

public fun validate(
    aggregator: &Aggregator,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    ctx: &mut TxContext
) {
    assert!(aggregator.version() == EXPECTED_AGGREGATOR_VERSION, EInvalidAggregatorVersion);
    assert!(aggregator.has_authority(ctx), EInvalidAuthority);
    assert!(min_sample_size > 0, EInvalidMinSampleSize);
    assert!(max_variance > 0, EInvalidMaxVariance);
    assert!(feed_hash.length() == 32, EInvalidFeedHash);
    assert!(min_responses > 0, EInvalidMinResponses);
    assert!(max_staleness_seconds > 0, EInvalidMaxStalenessSeconds);
}

fun actuate(
    aggregator: &mut Aggregator,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
) {
    aggregator.set_configs(
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
    );

    event::emit(AggregatorConfigsUpdated {
        aggregator_id: aggregator.id(),
        feed_hash: feed_hash,
        min_sample_size: min_sample_size,
        max_staleness_seconds: max_staleness_seconds,
        max_variance: max_variance,
        min_responses: min_responses,
    });
}

// initialize aggregator for user
public entry fun run(
    aggregator: &mut Aggregator,
    feed_hash: vector<u8>,
    min_sample_size: u64,
    max_staleness_seconds: u64,
    max_variance: u64,
    min_responses: u32,
    ctx: &mut TxContext
) {   
    validate(
        aggregator,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses,
        ctx
    );
    actuate(
        aggregator,
        feed_hash,
        min_sample_size,
        max_staleness_seconds,
        max_variance,
        min_responses
    );
}
