module switchboard::aggregator_delete_action;
 
use sui::event;
use switchboard::aggregator::Aggregator;

const EXPECTED_AGGREGATOR_VERSION: u8 = 1;

#[error]
const EInvalidAuthority: vector<u8> = b"Invalid authority";
#[error]
const EInvalidAggregatorVersion: vector<u8> = b"Invalid aggregator version";

public struct AggregatorDeleted has copy, drop {
    aggregator_id: ID,
}

public fun validate(aggregator: &Aggregator, ctx: &mut TxContext) {
    assert!(aggregator.version() == EXPECTED_AGGREGATOR_VERSION, EInvalidAggregatorVersion);
    assert!(aggregator.has_authority(ctx), EInvalidAuthority);
}

fun actuate(aggregator: Aggregator) {
    let update_event = AggregatorDeleted {
        aggregator_id: aggregator.id(),
    };
    aggregator.delete();
    event::emit(update_event);
}

public entry fun run(
    aggregator: Aggregator,
    ctx: &mut TxContext
) {   
    validate(&aggregator, ctx);
    actuate(aggregator);
}

