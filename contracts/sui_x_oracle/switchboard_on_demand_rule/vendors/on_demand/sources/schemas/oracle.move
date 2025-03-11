
module switchboard::oracle;

const ATTESTATION_TIMEOUT_MS: u64 = 1000 * 60 * 10; // 10 minutes
const VERSION: u8 = 1;

public struct Attestation has copy, store, drop {
    guardian_id: ID, 
    secp256k1_key: vector<u8>,
    timestamp_ms: u64,
}

public struct Oracle has key {
    id: UID,
    oracle_key: vector<u8>,
    queue: ID,
    queue_key: vector<u8>,        
    expiration_time_ms: u64,
    mr_enclave: vector<u8>,
    secp256k1_key: vector<u8>,
    valid_attestations: vector<Attestation>,
    version: u8,
}

public fun id(oracle: &Oracle): ID {
    oracle.id.to_inner()
}

public fun secp256k1_key(oracle: &Oracle): vector<u8> {
    oracle.secp256k1_key
}

public fun oracle_key(oracle: &Oracle): vector<u8> {
    oracle.oracle_key
}

public fun queue(oracle: &Oracle): ID {
    oracle.queue
}

public fun queue_key(oracle: &Oracle): vector<u8> {
    oracle.queue_key
}

public fun expiration_time_ms(oracle: &Oracle): u64 {
    oracle.expiration_time_ms
}

public fun guardian_id(attestation: &Attestation): ID {
    attestation.guardian_id
}

public fun oracle_secp256k1_key(attestation: &Attestation): vector<u8> {
    attestation.secp256k1_key
}

public fun timestamp_ms(attestation: &Attestation): u64 {
    attestation.timestamp_ms
}

public fun version(oracle: &Oracle): u8 {
    oracle.version
}

public(package) fun new(
    oracle_key: vector<u8>,
    queue: ID,
    queue_key: vector<u8>,
    ctx: &mut TxContext,
): ID {
    let id = object::new(ctx);
    let oracle_id = *(id.as_inner());
    let oracle = Oracle {
        id,
        oracle_key,
        queue,
        queue_key,
        expiration_time_ms: 0,
        secp256k1_key: vector::empty(),
        valid_attestations: vector::empty(),
        mr_enclave: vector::empty(),
        version: VERSION,
    };
    transfer::share_object(oracle);
    oracle_id
}

public(package) fun new_attestation(
    guardian_id: sui::object::ID,
    secp256k1_key: vector<u8>,
    timestamp_ms: u64,
): Attestation {
    Attestation {
        guardian_id,
        secp256k1_key,
        timestamp_ms,
    }
}

public(package) fun add_attestation(oracle: &mut Oracle, attestation: Attestation, timestamp_ms: u64) {
    oracle.valid_attestations = vector::filter!(oracle.valid_attestations, |a: &Attestation| {
        a.timestamp_ms + ATTESTATION_TIMEOUT_MS > timestamp_ms && a.guardian_id != attestation.guardian_id
    });
    vector::push_back(&mut oracle.valid_attestations, attestation);
}

public(package) fun valid_attestation_count(oracle: &Oracle, secp256k1_key: vector<u8>): u64 {
    vector::count!(&oracle.valid_attestations, |a: &Attestation| {
        a.secp256k1_key == secp256k1_key
    })
}

public(package) fun enable_oracle(
    oracle: &mut Oracle, 
    secp256k1_key: vector<u8>,
    mr_enclave: vector<u8>,
    expiration_time_ms: u64,
) {
    oracle.secp256k1_key = secp256k1_key;
    oracle.mr_enclave = mr_enclave;
    oracle.expiration_time_ms = expiration_time_ms;
}


#[test_only]
fun destroy_oracle(oracle: Oracle) {
    let Oracle {
        id,
        oracle_key: _,
        queue: _,
        queue_key: _,
        expiration_time_ms: _,
        secp256k1_key: _,
        valid_attestations: _,
        mr_enclave: _,
        version: _,
    } = oracle;
    object::delete(id);
 
 }


#[test]
fun test_create_oracle() {
    use sui::test_scenario;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();

    // just a random key
    let oracle_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let queue = object::id_from_address(@0x27);
    let queue_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";

    let oracle = Oracle {
        id: object::new(ctx),
        oracle_key,
        queue,
        queue_key,
        expiration_time_ms: 0,
        secp256k1_key: vector::empty(),
        valid_attestations: vector::empty(),
        mr_enclave: vector::empty(),
        version: VERSION,
    };

    // test accessors
    assert!(id(&oracle) == oracle.id.to_inner());
    assert!(secp256k1_key(&oracle) == vector::empty());
    assert!(oracle_key(&oracle) == oracle_key);
    assert!(queue(&oracle) == queue);
    assert!(queue_key(&oracle) == queue_key);
    assert!(expiration_time_ms(&oracle) == 0);
   
    destroy_oracle(oracle);
    test_scenario::end(scenario);
}

#[test]
public fun test_attestations() {
    use sui::test_scenario;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();

    let oracle_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let queue = object::id_from_address(@0x27);
    let queue_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let mut oracle = Oracle {
        id: object::new(ctx),
        oracle_key,
        queue,
        queue_key,
        expiration_time_ms: 0,
        secp256k1_key: vector::empty(),
        valid_attestations: vector::empty(),
        mr_enclave: vector::empty(),
        version: VERSION,
    };

    let guardian_id = object::id_from_address(@0x28);
    let secp256k1_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let timestamp_ms = 1000;
    let attestation = Attestation {
        guardian_id,
        secp256k1_key,
        timestamp_ms,
    };
    add_attestation(&mut oracle, attestation, timestamp_ms);
    assert!(valid_attestation_count(&oracle, secp256k1_key) == 1);

    let guardian_id = object::id_from_address(@0x28);
    let secp256k1_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let timestamp_ms = 1000;
    let attestation = Attestation {
        guardian_id,
        secp256k1_key,
        timestamp_ms,
    };
    add_attestation(&mut oracle, attestation, timestamp_ms);
    assert!(valid_attestation_count(&oracle, secp256k1_key) == 1);


    let guardian_id = object::id_from_address(@0x29);
    let secp256k1_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let timestamp_ms = 1000;
    let attestation = Attestation {
        guardian_id,
        secp256k1_key,
        timestamp_ms,
    };
    add_attestation(&mut oracle, attestation, timestamp_ms);
    assert!(valid_attestation_count(&oracle, secp256k1_key) == 2);

    let guardian_id = object::id_from_address(@0x31);
    let secp256k1_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let timestamp_ms = 1000;
    let attestation = Attestation {
        guardian_id,
        secp256k1_key,
        timestamp_ms,
    };
    add_attestation(&mut oracle, attestation, timestamp_ms);
    assert!(valid_attestation_count(&oracle, secp256k1_key) == 3);

    destroy_oracle(oracle);
    test_scenario::end(scenario);
}