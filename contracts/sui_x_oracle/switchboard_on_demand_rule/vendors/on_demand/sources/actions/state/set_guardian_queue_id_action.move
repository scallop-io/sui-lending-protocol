module switchboard::set_guardian_queue_id_action;

use sui::event;
use switchboard::on_demand::{Self, State, AdminCap};

public struct GuardianQueueIdSet has copy, drop {
    old_guardian_queue_id: ID,
    guardian_queue_id: ID,
}

public fun validate() {}

fun actuate(
    state: &mut State,
    guardian_queue_id: ID
) {
    let guardian_queue_id_set_event = GuardianQueueIdSet {
        old_guardian_queue_id: state.guardian_queue(),
        guardian_queue_id,
    };
    on_demand::set_guardian_queue_id(
        state,
        guardian_queue_id
    );
    event::emit(guardian_queue_id_set_event);
}

public entry fun run(
    _: &AdminCap,
    state: &mut State,
    guardian_queue_id: ID
) {   
    validate();
    actuate(state, guardian_queue_id);
}
