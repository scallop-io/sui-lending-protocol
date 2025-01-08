module switchboard::set_oracle_queue_id_action;

use sui::event;
use switchboard::on_demand::{Self, State, AdminCap};

public struct OracleQueueIdSet has copy, drop {
    old_oracle_queue_id: ID,
    oracle_queue_id: ID,
}

public fun validate() {}

fun actuate(
    state: &mut State,
    oracle_queue_id: ID
) {
    let oracle_queue_id_set_event = OracleQueueIdSet {
        old_oracle_queue_id: state.oracle_queue(),
        oracle_queue_id,
    };
    on_demand::set_oracle_queue_id(
        state,
        oracle_queue_id
    );
    event::emit(oracle_queue_id_set_event);
}

public entry fun run(
    _: &AdminCap,
    state: &mut State,
    oracle_queue_id: ID
) {   
    validate();
    actuate(state, oracle_queue_id);
}
