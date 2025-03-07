module switchboard::queue_override_oracle_action;

use sui::clock::Clock;
use sui::event;
use switchboard::oracle::Oracle;
use switchboard::queue::Queue;

const EXPECTED_ORACLE_VERSION: u8 = 1;
const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
#[error]
const EInvalidExpirationTime: vector<u8> = b"Invalid expiration time";
#[error]
const EInvalidQueueId: vector<u8> = b"Invalid queue id";
#[error]
const EInvalidQueueKey: vector<u8> = b"Invalid queue key";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";
#[error]
const EInvalidOracleVersion: vector<u8> = b"Invalid oracle version";

public struct QueueOracleOverride has copy, drop {
    queue_id: ID,
    oracle_id: ID,
    secp256k1_key: vector<u8>,
    mr_enclave: vector<u8>,
    expiration_time_ms: u64,
}

public fun validate(
    queue: &Queue,
    oracle: &Oracle, 
    expiration_time_ms: u64,
    ctx: &mut TxContext
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(oracle.version() == EXPECTED_ORACLE_VERSION, EInvalidOracleVersion);
    assert!(queue.queue_key() == oracle.queue_key(), EInvalidQueueKey);
    assert!(queue.id() == oracle.queue(), EInvalidQueueId);
    assert!(queue.has_authority(ctx), EInvalidAuthority);
    assert!(expiration_time_ms > 0, EInvalidExpirationTime);
}

fun actuate(
    oracle: &mut Oracle,
    queue: &mut Queue,
    secp256k1_key: vector<u8>,
    mr_enclave: vector<u8>,
    expiration_time_ms: u64,
    clock: &Clock,
) {
    oracle.enable_oracle(
        secp256k1_key,
        mr_enclave,
        expiration_time_ms,
    ); 

    queue.set_last_queue_override_ms(clock.timestamp_ms());

    // emit queue override event
    let queue_override_event = QueueOracleOverride {
        oracle_id: oracle.id(),
        queue_id: queue.id(),
        secp256k1_key: secp256k1_key,
        mr_enclave: mr_enclave,
        expiration_time_ms: expiration_time_ms,
    };
    event::emit(queue_override_event);
}

// initialize aggregator for user
public entry fun run(
    queue: &mut Queue,
    oracle: &mut Oracle,
    secp256k1_key: vector<u8>,
    mr_enclave: vector<u8>,
    expiration_time_ms: u64,
    clock: &Clock,
    ctx: &mut TxContext
) {   
    validate(
        queue,
        oracle,
        expiration_time_ms,
        ctx,
    );
    actuate(
        oracle,
        queue,
        secp256k1_key,
        mr_enclave,
        expiration_time_ms,
        clock,
    );
}
