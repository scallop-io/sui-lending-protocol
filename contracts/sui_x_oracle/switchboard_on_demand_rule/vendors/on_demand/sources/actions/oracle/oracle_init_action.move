module switchboard::oracle_init_action;
 
use sui::event;
use switchboard::queue::Queue;
use switchboard::oracle;

const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EOracleKeyExists: vector<u8> = b"Oracle already exists on Queue";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct OracleCreated has copy, drop {
    oracle_id: ID,
    queue_id: ID,
    oracle_key: vector<u8>,
}

public fun validate(
    oracle_key: &vector<u8>,
    queue: &Queue,
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(!queue.existing_oracles_contains(*oracle_key), EOracleKeyExists);
}

fun actuate(
    queue: &mut Queue,
    oracle_key: vector<u8>,
    ctx: &mut TxContext,
) {
    let oracle_id = oracle::new(
        oracle_key,
        queue.id(),
        queue.queue_key(),
        ctx,
    );
    queue.add_existing_oracle(oracle_key, oracle_id);

    // emit oracle init event
    let created_event = OracleCreated {
        oracle_id,
        queue_id: queue.id(),
        oracle_key,
    };
    event::emit(created_event);
}

public entry fun run(
    oracle_key: vector<u8>,
    queue: &mut Queue,
    ctx: &mut TxContext
) {   
    validate(
        &oracle_key,
        queue,
    );
    actuate(
        queue,
        oracle_key,
        ctx,
    );
}
