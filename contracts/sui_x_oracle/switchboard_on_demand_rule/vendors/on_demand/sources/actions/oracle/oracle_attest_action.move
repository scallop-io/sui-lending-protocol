module switchboard::oracle_attest_action;
 
use sui::clock::Clock;
use sui::ecdsa_k1;
use sui::event;
use switchboard::hash;
use switchboard::queue::Queue;
use switchboard::oracle::{Self, Oracle};

const EXPECTED_ORACLE_VERSION: u8 = 1;
const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidGuardianQueue: vector<u8> = b"Invalid guardian queue";
#[error]
const EGuardianInvalid: vector<u8> = b"Guardian is invalid";
#[error]
const EWrongSignatureLength: vector<u8> = b"Signature is the wrong length";
#[error]
const ETimestampInvalid: vector<u8> = b"Timestamp is invalid";
#[error]
const EInvalidSignature: vector<u8> = b"Invalid signature";
#[error]
const EInvalidOracleVersion: vector<u8> = b"Invalid oracle version";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct AttestationCreated has copy, drop {
    oracle_id: ID,
    guardian_id: ID,
    secp256k1_key: vector<u8>,
    timestamp_ms: u64,
}

public struct AttestationResolved has copy, drop {
    oracle_id: ID,
    secp256k1_key: vector<u8>,
    timestamp_ms: u64,
}

const ATTESTATION_VALIDITY_MS: u64 = 1000 * 60 * 60 * 10;

public fun validate(
    oracle: &mut Oracle,
    queue: &Queue,
    guardian: &Oracle,
    timestamp_seconds: u64,
    mr_enclave: vector<u8>,
    secp256k1_key: vector<u8>,
    signature: vector<u8>,
    clock: &Clock,
) {

    // check the queue version
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);

    // check the oracle version
    assert!(oracle.version() == EXPECTED_ORACLE_VERSION, EInvalidOracleVersion);
    
    // check the guardian version
    assert!(guardian.version() == EXPECTED_ORACLE_VERSION, EInvalidOracleVersion);

    // check that guardian queue (for the target queue) is the guardian's queue
    assert!(guardian.queue() == queue.guardian_queue_id(), EInvalidGuardianQueue);

    // check that the guardian is valid
    assert!(oracle.expiration_time_ms() > clock.timestamp_ms(), EGuardianInvalid);

    // check that the signature is valid length
    assert!(signature.length() == 65, EWrongSignatureLength);

    // check that the timestamp is a maximum of 10 minutes old (and not in the future)
    assert!(timestamp_seconds * 1000 + ATTESTATION_VALIDITY_MS >= clock.timestamp_ms(), ETimestampInvalid);
    
    // check that signature maps to the guardian, and that the guardian is valid
    let oracle_key = oracle.oracle_key();
    let queue_key = oracle.queue_key();
    let attestation_msg = hash::generate_attestation_msg(
        oracle_key,
        queue_key,
        mr_enclave,
        x"0000000000000000000000000000000000000000000000000000000000000000",
        secp256k1_key,
        timestamp_seconds,
    );

    // recover the guardian pubkey from the signature
    let recovered_pubkey_compressed = ecdsa_k1::secp256k1_ecrecover(&signature, &attestation_msg, 1);
    let recovered_pubkey = ecdsa_k1::decompress_pubkey(&recovered_pubkey_compressed);

    // check that the recovered pubkey is valid
    assert!(hash::check_subvec(&recovered_pubkey, &guardian.secp256k1_key(), 1), EInvalidSignature);
}

fun actuate(
    oracle: &mut Oracle,
    queue: &Queue,
    guardian: &Oracle,
    timestamp_seconds: u64,
    mr_enclave: vector<u8>,
    secp256k1_key: vector<u8>,
    clock: &Clock,
) {
    let attestation = oracle::new_attestation( 
        guardian.id(),
        secp256k1_key,
        timestamp_seconds * 1000,
    );
    oracle.add_attestation(attestation, clock.timestamp_ms());

    // emit creation event
    let attestation_created = AttestationCreated {
        oracle_id: oracle.id(),
        guardian_id: guardian.id(),
        secp256k1_key,
        timestamp_ms: clock.timestamp_ms(),
    };
    event::emit(attestation_created);

    let valid_attestations = oracle.valid_attestation_count(secp256k1_key);
    if (valid_attestations >= queue.min_attestations()) {
        let expiration_time_ms = clock.timestamp_ms() + queue.oracle_validity_length_ms();
        oracle.enable_oracle(secp256k1_key, mr_enclave, expiration_time_ms);
        
        // emit resolution event
        let attestation_resolved = AttestationResolved {
            oracle_id: oracle.id(),
            secp256k1_key,
            timestamp_ms: clock.timestamp_ms(),
        };
        event::emit(attestation_resolved);
    };
}

public entry fun run(
    oracle: &mut Oracle,
    queue: &Queue,
    guardian: &Oracle,
    timestamp_seconds: u64,
    mr_enclave: vector<u8>,
    secp256k1_key: vector<u8>,
    signature: vector<u8>,
    clock: &Clock,
) {
    validate(
        oracle,
        queue,
        guardian,
        timestamp_seconds,
        mr_enclave,
        secp256k1_key,
        signature,
        clock,
    );
    actuate(
        oracle,
        queue,
        guardian,
        timestamp_seconds,
        mr_enclave,
        secp256k1_key,
        clock,
    );
}
