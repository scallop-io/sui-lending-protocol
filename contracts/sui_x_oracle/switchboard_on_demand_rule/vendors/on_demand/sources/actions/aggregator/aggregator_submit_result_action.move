module switchboard::aggregator_submit_result_action;

use sui::clock::Clock;
use sui::coin::Coin;
use sui::ecdsa_k1;
use switchboard::decimal::{Self, Decimal};
use switchboard::hash;
use switchboard::aggregator::Aggregator;
use switchboard::oracle::Oracle;
use switchboard::queue::Queue;
use sui::event;

const EXPECTED_AGGREGATOR_VERSION: u8 = 1;
const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EOracleInvalid: vector<u8> = b"Oracle is invalid";
#[error]
const EAggregatorQueueMismatch: vector<u8> = b"Aggregator queue mismatch";
#[error]
const ETimestampInvalid: vector<u8> = b"Timestamp is invalid";
#[error]
const ESignatureInvalid: vector<u8> = b"Signature is invalid";
#[error]
const ERecoveredPubkeyInvalid: vector<u8> = b"Recovered pubkey is invalid";
#[error]
const EInvalidFeeType: vector<u8> = b"Invalid fee type";
#[error]
const EInsufficientFee: vector<u8> = b"Insufficient fee";
#[error]
const EInvalidAggregatorVersion: vector<u8> = b"Invalid aggregator version";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct AggregatorUpdated has copy, drop {
    aggregator_id: ID,
    oracle_id: ID,
    value: Decimal,
    timestamp_ms: u64,
}

public fun validate<T>(
    aggregator: &Aggregator,
    queue: &Queue,
    oracle: &Oracle,
    timestamp_seconds: u64,
    value: &Decimal,
    signature: vector<u8>,
    clock: &Clock,
    coin: &Coin<T>,
) {

    // check that the versions are correct
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);

    // check that the aggregator version is correct
    assert!(aggregator.version() == EXPECTED_AGGREGATOR_VERSION, EInvalidAggregatorVersion);

    // verify that the oracle is servicing the correct queue
    assert!(oracle.queue() == aggregator.queue(), EAggregatorQueueMismatch);

    // verify that the oracle is up
    assert!(oracle.expiration_time_ms() > clock.timestamp_ms(), EOracleInvalid);

    // make sure that update staleness point is not in the future
    assert!(timestamp_seconds * 1000 + aggregator.max_staleness_seconds() * 1000 >= clock.timestamp_ms(), ETimestampInvalid);

    // check that the signature is valid length
    assert!(signature.length() == 65, ESignatureInvalid);

    // check that the signature is valid
    let update_msg = hash::generate_update_msg(
        value,
        oracle.queue_key(),
        aggregator.feed_hash(),
        x"0000000000000000000000000000000000000000000000000000000000000000",
        aggregator.max_variance(),
        aggregator.min_responses(),
        timestamp_seconds,
    );

    // recover the pubkey from the signature
    let recovered_pubkey_compressed = ecdsa_k1::secp256k1_ecrecover(
        &signature, 
        &update_msg, 
        1,
    );
    let recovered_pubkey = ecdsa_k1::decompress_pubkey(&recovered_pubkey_compressed);

    // check that the recovered pubkey is valid
    assert!(hash::check_subvec(&recovered_pubkey, &oracle.secp256k1_key(), 1), ERecoveredPubkeyInvalid);

    // fee check
    assert!(queue.has_fee_type<T>(), EInvalidFeeType);
    assert!(coin.value() >= queue.fee(), EInsufficientFee);
}

fun actuate<T>(
    aggregator: &mut Aggregator,
    queue: &Queue,
    value: Decimal,
    timestamp_seconds: u64,
    oracle: &Oracle,
    clock: &Clock,
    fee: Coin<T>,
) {

    // timestamp in ms
    let timestamp_ms = timestamp_seconds * 1000;

    // add the result to the aggregator
    aggregator.add_result(
        value, 
        timestamp_ms, 
        oracle.id(), 
        clock,
    );

    // transfer the fee to the queue's fee recipient
    transfer::public_transfer(fee, queue.fee_recipient());

    // emit an event
    event::emit(AggregatorUpdated {
        aggregator_id: aggregator.id(),
        oracle_id: oracle.id(),
        value,
        timestamp_ms,
    });

}

// initialize aggregator for user
public entry fun run<T>(
    aggregator: &mut Aggregator,
    queue: &Queue,
    value: u128,
    neg: bool,
    timestamp_seconds: u64,
    oracle: &Oracle,
    signature: vector<u8>,
    clock: &Clock,
    fee: Coin<T>,
) {
    let value = decimal::new(value, neg);
    validate<T>(aggregator, queue, oracle, timestamp_seconds, &value, signature, clock, &fee);
    actuate(aggregator, queue, value, timestamp_seconds, oracle, clock, fee);
}
