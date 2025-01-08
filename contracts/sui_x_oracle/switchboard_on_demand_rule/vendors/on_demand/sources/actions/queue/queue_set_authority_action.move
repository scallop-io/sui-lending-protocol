module switchboard::queue_set_authority_action;
 
use sui::event;
use switchboard::queue::Queue;

const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct QueueAuthorityUpdated has copy, drop {
    queue_id: ID,
    existing_authority: address,
    new_authority: address,
}

public fun validate(
    queue: &Queue,
    ctx: &mut TxContext
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(queue.has_authority(ctx), EInvalidAuthority);
}

fun actuate(
    queue: &mut Queue,
    new_authority: address,
) {
    let update_event = QueueAuthorityUpdated {
        queue_id: queue.id(),
        existing_authority: queue.authority(),
        new_authority: new_authority,
    };
    queue.set_authority(new_authority);
    event::emit(update_event);
}

public entry fun run(
    queue: &mut Queue,
    new_authority: address,
    ctx: &mut TxContext
) {   
    validate(
        queue,
        ctx,
    );
    actuate(
        queue,
        new_authority,
    );
}
