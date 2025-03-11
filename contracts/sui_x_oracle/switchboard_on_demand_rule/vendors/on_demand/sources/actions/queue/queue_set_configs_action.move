module switchboard::queue_set_configs_action;

use sui::event;
use std::string::String;
use switchboard::queue::Queue;

const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
#[error]
const EInvalidOracleValidityLength: vector<u8> = b"Invalid oracle validity length";
#[error]
const EInvalidMinAttestations: vector<u8> = b"Invalid min attestations";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct QueueConfigsUpdated has copy, drop {
    queue_id: ID,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
}

public fun validate(
    queue: &Queue,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    ctx: &TxContext
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(queue.has_authority(ctx), EInvalidAuthority);
    assert!(min_attestations > 0, EInvalidMinAttestations);
    assert!(oracle_validity_length_ms > 0, EInvalidOracleValidityLength);
}

fun actuate(
    queue: &mut Queue,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
) {
    queue.set_configs(
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
    );

    let update_event = QueueConfigsUpdated {
        queue_id: queue.id(),
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
    };
    event::emit(update_event);
}

// initialize aggregator for user
public entry fun run(
    queue: &mut Queue,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    ctx: &mut TxContext
) {
    validate(
        queue,
        min_attestations,
        oracle_validity_length_ms,
        ctx,
    );
    actuate(
        queue,
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
    );
}

