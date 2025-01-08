module switchboard::set_package_id_action;


use sui::event;
use switchboard::on_demand::{Self, State, AdminCap};

public struct OnDemandPackageIdSet has copy, drop {
    old_on_demand_package_id: ID,
    on_demand_package_id: ID,
}

public fun validate() {}

fun actuate(
    state: &mut State,
    on_demand_package_id: ID
) {
    let on_demand_package_id_set_event = OnDemandPackageIdSet {
        old_on_demand_package_id: state.on_demand_package_id(),
        on_demand_package_id,
    };
    on_demand::set_on_demand_package_id(
        state,
        on_demand_package_id
    );
    event::emit(on_demand_package_id_set_event);
}

public entry fun run(
    _: &AdminCap,
    state: &mut State,
    on_demand_package_id: ID
) {   
    validate();
    actuate(state, on_demand_package_id);
}
