module switchboard::hash;
 
use std::hash;
use std::bcs;
use std::u128;
use switchboard::decimal::{Self, Decimal};

#[error]
const EWrongFeedHashLength: vector<u8> = b"Feed hash must be 32 bytes";
#[error]
const EWrongOracleIdLength: vector<u8> = b"Oracle ID must be 32 bytes";
#[error]
const EWrongSlothashLength: vector<u8> = b"Slothash must be 32 bytes";
#[error]
const EWrongQueueLength: vector<u8> = b"Queue must be 32 bytes";
#[error]
const EWrongMrEnclaveLength: vector<u8> = b"MR Enclave must be 32 bytes";
#[error]
const EWrongSec256k1KeyLength: vector<u8> = b"Secp256k1 key must be 64 bytes";


public struct Hasher has drop, copy {
    buffer: vector<u8>,
}

public fun new(): Hasher {
    Hasher {
        buffer: vector::empty(),
    }
}

public fun finalize(self: &Hasher): vector<u8> {
    hash::sha2_256(self.buffer)
}

public fun push_u8(self: &mut Hasher, value: u8) {
    self.buffer.push_back(value);
}

public fun push_u32(self: &mut Hasher, value: u32) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_u32_le(self: &mut Hasher, value: u32) {
    let bytes = bcs::to_bytes(&value);
    self.buffer.append(bytes);
}

public fun push_u64(self: &mut Hasher, value: u64) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_u64_le(self: &mut Hasher, value: u64) {
    let bytes = bcs::to_bytes(&value);
    self.buffer.append(bytes);
}

public fun push_u128(self: &mut Hasher, value: u128) {
    let mut bytes = bcs::to_bytes(&value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_i128(self: &mut Hasher, value: u128, neg: bool) {

    let signed_value: u128 = if (neg) {
        // Get two's complement by subtracting from 2^128
        u128::max_value!() - value + 1
    } else {
        value
    };

    let mut bytes = bcs::to_bytes(&signed_value);
    vector::reverse(&mut bytes);
    self.buffer.append(bytes);
}

public fun push_i128_le(self: &mut Hasher, value: u128, neg: bool) {
    let signed_value: u128 = if (neg) {
        // Get two's complement by subtracting from 2^128
        u128::max_value!() - value + 1
    } else {
        value
    };
    let bytes = bcs::to_bytes(&signed_value);
    self.buffer.append(bytes);
}

public fun push_decimal(self: &mut Hasher, value: &Decimal) {
    let (value, neg) = decimal::unpack(*value);
    self.push_i128(value, neg);
}

public fun push_decimal_le(self: &mut Hasher, value: &Decimal) {
    let (value, neg) = decimal::unpack(*value);
    self.push_i128_le(value, neg);
}


public fun push_bytes(self: &mut Hasher, bytes: vector<u8>) {
    self.buffer.append(bytes);
}

public fun generate_update_msg(
    value: &Decimal,
    queue_key: vector<u8>,
    feed_hash: vector<u8>,
    slothash: vector<u8>,
    max_variance: u64,
    min_responses: u32,
    timestamp: u64,
): vector<u8> {
    let mut hasher = new();
    assert!(queue_key.length() == 32, EWrongQueueLength);
    assert!(feed_hash.length() == 32, EWrongFeedHashLength);
    assert!(slothash.length() == 32, EWrongSlothashLength);
    hasher.push_bytes(queue_key);
    hasher.push_bytes(feed_hash);
    hasher.push_decimal_le(value);
    hasher.push_bytes(slothash);
    hasher.push_u64_le(max_variance);
    hasher.push_u32_le(min_responses);
    hasher.push_u64_le(timestamp);
    let Hasher { buffer } = hasher;
    buffer
}

public fun generate_attestation_msg(
    oracle_key: vector<u8>, 
    queue_key: vector<u8>,
    mr_enclave: vector<u8>,
    slothash: vector<u8>,
    secp256k1_key: vector<u8>,
    timestamp: u64,
): vector<u8> {
    let mut hasher = new();
    assert!(oracle_key.length() == 32, EWrongOracleIdLength);
    assert!(queue_key.length() == 32, EWrongQueueLength);
    assert!(mr_enclave.length() == 32, EWrongMrEnclaveLength);
    assert!(slothash.length() == 32, EWrongSlothashLength);
    assert!(secp256k1_key.length() == 64, EWrongSec256k1KeyLength);
    hasher.push_bytes(oracle_key);
    hasher.push_bytes(queue_key);
    hasher.push_bytes(mr_enclave);
    hasher.push_bytes(slothash);
    hasher.push_bytes(secp256k1_key);
    hasher.push_u64_le(timestamp);
    let Hasher { buffer } = hasher;
    buffer
}

public fun check_subvec(v1: &vector<u8>, v2: &vector<u8>, start_idx: u64): bool {
    if (v1.length() < start_idx + v2.length()) {
        return false
    };

    let mut iterations = v2.length();
    while (iterations > 0) {
        let idx = iterations - 1;
        if (v1[start_idx + idx] != v2[idx]) {
            return false
        };
        iterations = iterations - 1;
    };

    true
}

#[test]
fun test_update_msg() { 
    let value = decimal::new(226943873990930561085963032052770576810, false);
    let queue_key = x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let feed_hash = x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    let slothash = x"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
    let max_variance: u64 = 42;  
    let min_responses: u32 = 3;
    let timestamp: u64 = 1620000000;
    let value_num: u128 = 226943873990930561085963032052770576810;
    let msg = generate_update_msg(
        &value,
        queue_key,
        feed_hash,
        slothash,
        max_variance,
        min_responses,
        timestamp,
    );
    test_check_subvec(&msg, &queue_key, 0);
    test_check_subvec(&msg, &feed_hash, 32);
    test_check_subvec(&msg, &bcs::to_bytes(&value_num), 64);
    test_check_subvec(&msg, &slothash, 80);
    test_check_subvec(&msg, &bcs::to_bytes(&max_variance), 112);
    test_check_subvec(&msg, &bcs::to_bytes(&min_responses), 120);
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 124);
}

#[test]
fun test_update_msg_ecrecover() { 
    let value = decimal::new(66681990000000000000000, false);
    let queue_key = x"86807068432f186a147cf0b13a30067d386204ea9d6c8b04743ac2ef010b0752";
    let feed_hash = x"013b9b2fb2bdd9e3610df0d7f3e31870a1517a683efb0be2f77a8382b4085833";
    let slothash = x"0000000000000000000000000000000000000000000000000000000000000000";
    let max_variance: u64 = 5000000000;  
    let min_responses: u32 = 1;
    let timestamp: u64 = 1729903069;
    let signature = x"0544f0348504715ecbf8ce081a84dd845067ae2a11d4315e49c4a49f78ad97bf650fe6c17c28620cbe18043b66783fcc09fcd540c2b9e2dabf2159f078daa14500";
    let msg = generate_update_msg(
        &value,
        queue_key,
        feed_hash,
        slothash,
        max_variance,
        min_responses,
        timestamp,
    );
    let recovered_pubkey = sui::ecdsa_k1::secp256k1_ecrecover(
        &signature, 
        &msg, 
        1,
    );
    let decompressed_pubkey = sui::ecdsa_k1::decompress_pubkey(&recovered_pubkey);
    let expected_signer = x"23dcf1a2dcadc1c196111baaa62ab0d1276e6f928ce274d2898f29910cc4df45e18a642df3cc82e73e978237abbae7e937f1af41b0dcc179b102f7b4c8958121";
    test_check_subvec(&decompressed_pubkey, &expected_signer, 1);
}



#[test]
fun test_attestation_msg() { 
    let oracle_key = x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    let queue_key = x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    let mr_enclave = x"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
    let slothash = x"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd";
    let secp256k1_key = x"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
    let timestamp: u64 = 1620000000;
    let msg = generate_attestation_msg(
        oracle_key,
        queue_key,
        mr_enclave,
        slothash,
        secp256k1_key,
        timestamp,
    );
    test_check_subvec(&msg, &oracle_key, 0);
    test_check_subvec(&msg, &queue_key, 32);
    test_check_subvec(&msg, &mr_enclave, 64);
    test_check_subvec(&msg, &slothash, 96);
    test_check_subvec(&msg, &secp256k1_key, 128);
    test_check_subvec(&msg, &bcs::to_bytes(&timestamp), 192);
}

#[test_only]
fun test_check_subvec(v1: &vector<u8>, v2: &vector<u8>, start_idx: u64) {
    assert!(v1.length() >= start_idx + v2.length());
    let mut iterations = v2.length();
    while (iterations > 0) {
        let idx = iterations - 1;
        assert!(v1[start_idx + idx] == v2[idx], idx as u64);
        iterations = iterations - 1;
    }
}