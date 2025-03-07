module switchboard::queue_add_fee_coin_action;
 
use sui::coin::Coin;
use sui::event;
use std::type_name::{Self, TypeName};
use switchboard::queue::Queue;

const EXPECTED_QUEUE_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
#[error]
const EInvalidQueueVersion: vector<u8> = b"Invalid queue version";

public struct QueueFeeTypeAdded has copy, drop {
    queue_id: ID,
    fee_type: TypeName,
}

public fun validate(
    queue: &Queue,
    ctx: &mut TxContext
) {
    assert!(queue.version() == EXPECTED_QUEUE_VERSION, EInvalidQueueVersion);
    assert!(queue.has_authority(ctx), EInvalidAuthority);
}

fun actuate<T>(
    queue: &mut Queue,
) {
    queue.add_fee_type<T>();
    event::emit(QueueFeeTypeAdded {
        queue_id: queue.id(),
        fee_type: type_name::get<Coin<T>>(),
    });
}

public entry fun run<T>(
    queue: &mut Queue,
    ctx: &mut TxContext
) {   
    validate(
        queue,
        ctx,
    );
    actuate<T>(queue);
}
