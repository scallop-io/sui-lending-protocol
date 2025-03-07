module switchboard::queue;

use std::type_name::{Self, TypeName};
use std::string::String;
use sui::coin::Coin;
use sui::sui::SUI;
use sui::table::{Self, Table};

const VERSION: u8 = 1;

public struct ExistingOracle has copy, drop, store {
    oracle_id: ID,
    oracle_key: vector<u8>,
}

public struct Queue has key {
    id: UID,
    queue_key: vector<u8>,
    authority: address,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    last_queue_override_ms: u64,
    guardian_queue_id: ID,

    // to ensure that oracles are only mapped once (oracle pubkeys)
    existing_oracles: Table<vector<u8>, ExistingOracle>,
    fee_types: vector<TypeName>,
    version: u8,
}

public fun id(queue: &Queue): ID {
    queue.id.to_inner()
}

public fun queue_key(queue: &Queue): vector<u8> {
    queue.queue_key
}

public fun authority(queue: &Queue): address {
    queue.authority
}

public fun name(queue: &Queue): String {
    queue.name
}

public fun fee(queue: &Queue): u64 {
    queue.fee
}

public fun fee_recipient(queue: &Queue): address {
    queue.fee_recipient
}

public fun min_attestations(queue: &Queue): u64 {
    queue.min_attestations
}

public fun oracle_validity_length_ms(queue: &Queue): u64 {
    queue.oracle_validity_length_ms
}

public fun last_queue_override_ms(queue: &Queue): u64 {
    queue.last_queue_override_ms
}

public fun guardian_queue_id(queue: &Queue): ID {
    queue.guardian_queue_id
}

public fun existing_oracles(queue: &Queue): &Table<vector<u8>, ExistingOracle> {
    &queue.existing_oracles
}

public fun fee_types(queue: &Queue): vector<TypeName> {
    queue.fee_types
}

public fun version(queue: &Queue): u8 {
    queue.version
}

public fun existing_oracles_contains(queue: &Queue, oracle_key: vector<u8>): bool {
    queue.existing_oracles.contains(oracle_key)
}

public fun has_authority(queue: &Queue, ctx: &TxContext): bool {
    queue.authority == ctx.sender()
}

public fun has_fee_type<T>(queue: &Queue): bool {
    queue.fee_types.contains(&type_name::get<Coin<T>>())
}

public fun oracle_id(oracle: &ExistingOracle): ID {
    oracle.oracle_id
}

public fun oracle_key(oracle: &ExistingOracle): vector<u8> {
    oracle.oracle_key
}

public(package) fun new(
    queue_key: vector<u8>,
    authority: address,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
    guardian_queue_id: ID,
    is_guardian_queue: bool,
    ctx: &mut TxContext,
): ID {
    let id = object::new(ctx);
    let queue_id = *(id.as_inner());
    if (is_guardian_queue) {
        let guardian_queue_id = *(id.as_inner());
        let guardian_queue = Queue {
            id,
            queue_key,
            authority,
            name,
            fee,
            fee_recipient,
            min_attestations,
            oracle_validity_length_ms,
            last_queue_override_ms: 0,
            guardian_queue_id,
            existing_oracles: table::new(ctx),
            fee_types: vector::singleton(type_name::get<Coin<SUI>>()),
            version: VERSION,
        };
        transfer::share_object(guardian_queue);
    } else {
        let oracle_queue = Queue {
            id,
            queue_key,
            authority,
            name,
            fee,
            fee_recipient,
            min_attestations,
            oracle_validity_length_ms,
            last_queue_override_ms: 0,
            guardian_queue_id,
            existing_oracles: table::new(ctx),
            fee_types: vector::singleton(type_name::get<Coin<SUI>>()),
            version: VERSION,
        };
        transfer::share_object(oracle_queue);
    };

    queue_id
}

public(package) fun add_existing_oracle(queue: &mut Queue, oracle_key: vector<u8>, oracle_id: ID) {
    queue.existing_oracles.add(oracle_key, ExistingOracle { oracle_id, oracle_key });
}

public(package) fun set_last_queue_override_ms(queue: &mut Queue, last_queue_override_ms: u64) {
    queue.last_queue_override_ms = last_queue_override_ms;
}

public(package) fun set_guardian_queue_id(queue: &mut Queue, guardian_queue_id: ID) {
    queue.guardian_queue_id = guardian_queue_id;
} 

public(package) fun set_queue_key(queue: &mut Queue, queue_key: vector<u8>) {
    queue.queue_key = queue_key;
}

public(package) fun set_authority(queue: &mut Queue, authority: address) {
    queue.authority = authority;
}

public(package) fun set_configs(
    queue: &mut Queue,
    name: String,
    fee: u64,
    fee_recipient: address,
    min_attestations: u64,
    oracle_validity_length_ms: u64,
) {
    queue.name = name;
    queue.fee = fee;
    queue.fee_recipient = fee_recipient;
    queue.min_attestations = min_attestations;
    queue.oracle_validity_length_ms = oracle_validity_length_ms;
}

public (package) fun add_fee_type<T>(queue: &mut Queue) {
    if (queue.fee_types.contains(&type_name::get<Coin<T>>())) {
        return
    };
    queue.fee_types.push_back(type_name::get<Coin<T>>());
}

public (package) fun remove_fee_type<T>(queue: &mut Queue) {
    let (has_type, index) = queue.fee_types.index_of(&type_name::get<Coin<T>>());
    if (has_type == false) {
        return
    };
    queue.fee_types.swap_remove(index);
}


#[test_only]
fun destroy_queue(queue: Queue) {
    let Queue {
        id,
        queue_key: _,
        authority: _,
        name: _,
        fee: _,
        fee_recipient: _,
        min_attestations: _,
        oracle_validity_length_ms: _,
        last_queue_override_ms: _,
        guardian_queue_id: _,
        existing_oracles,
        fee_types: _,
        version: _,
    } = queue;
    existing_oracles.drop();
    object::delete(id);
}

#[test]
fun test_init_queue() {
    use sui::test_scenario;
    use std::string;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();

    let queue_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let authority = @0x27;
    let name = string::utf8(b"Mainnet Guardian Queue");
    let fee = 0;
    let fee_recipient = @0x27;
    let min_attestations = 3;
    let oracle_validity_length_ms = 1000 * 60 * 60 * 24 * 365 * 5;
    let guardian_queue_id = object::id_from_address(@0x963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c);

    let queue = Queue {
        id: object::new(ctx),
        queue_key,
        authority,
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
        last_queue_override_ms: 0,
        guardian_queue_id,
        existing_oracles: table::new(ctx),
        fee_types: vector::empty(),
        version: VERSION,
    };

    assert!(id(&queue) == queue.id.to_inner());
    assert!(queue_key(&queue) == queue_key);
    assert!(authority(&queue) == authority);
    assert!(name(&queue) == name);
    assert!(fee(&queue) == fee);
    assert!(fee_recipient(&queue) == fee_recipient);
    assert!(min_attestations(&queue) == min_attestations);
    assert!(oracle_validity_length_ms(&queue) == oracle_validity_length_ms);
    assert!(last_queue_override_ms(&queue) == 0);
    assert!(guardian_queue_id(&queue) == guardian_queue_id);
    destroy_queue(queue);
    test_scenario::end(scenario);
}

#[test]
fun test_queue_set_configs() {
    use sui::test_scenario;
    use std::string;
    let owner = @0x26;
    let mut scenario = test_scenario::begin(owner);
    let ctx = scenario.ctx();

    let queue_key = x"963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c";
    let authority = @0x27;
    let name = string::utf8(b"Mainnet Guardian Queue");
    let fee = 0;
    let fee_recipient = @0x27;
    let min_attestations = 3;
    let oracle_validity_length_ms = 1000 * 60 * 60 * 24 * 365 * 5;
    let guardian_queue_id = object::id_from_address(@0x963fead0d455c024345ec1c3726843693bbe6426825862a6d38ba9ccd8e5bd7c);

    let mut queue = Queue {
        id: object::new(ctx),
        queue_key,
        authority,
        name,
        fee,
        fee_recipient,
        min_attestations,
        oracle_validity_length_ms,
        last_queue_override_ms: 0,
        guardian_queue_id,
        existing_oracles: table::new(ctx),
        fee_types: vector::empty(),
        version: VERSION,
    };

    let new_name = string::utf8(b"Mainnet Oracle Queue");
    let new_fee = 0;
    let new_fee_recipient = @0x27;
    let new_min_attestations = 3;
    let new_oracle_validity_length_ms = 1000 * 60 * 60 * 24 * 365 * 5;

    set_configs(
        &mut queue,
        new_name,
        new_fee,
        new_fee_recipient,
        new_min_attestations,
        new_oracle_validity_length_ms,
    );

    assert!(name(&queue) == new_name);
    assert!(fee(&queue) == new_fee);
    assert!(fee_recipient(&queue) == new_fee_recipient);
    assert!(min_attestations(&queue) == new_min_attestations);
    assert!(oracle_validity_length_ms(&queue) == new_oracle_validity_length_ms);
    destroy_queue(queue);
    test_scenario::end(scenario);
}