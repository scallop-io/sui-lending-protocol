module switchboard::on_demand;

use sui::package;

public struct ON_DEMAND has drop {}

public struct State has key {
    id: UID,
    oracle_queue: ID,
    guardian_queue: ID,
    on_demand_package_id: ID,
}

public struct AdminCap has key {
    id: UID,
}

public fun oracle_queue(state: &State): ID {
    state.oracle_queue
}

public fun guardian_queue(state: &State): ID {
    state.guardian_queue
}

fun init(otw: ON_DEMAND, ctx: &mut TxContext) {
    package::claim_and_keep(otw, ctx);
    // Share the state object
    let state = State {
        id: object::new(ctx),
        oracle_queue: object::id_from_address(@0x0000000000000000000000000000000000000000000000000000000000000000),
        guardian_queue: object::id_from_address(@0x0000000000000000000000000000000000000000000000000000000000000000),
        on_demand_package_id: object::id_from_address(@0x0000000000000000000000000000000000000000000000000000000000000000),
    };

    transfer::share_object(state);
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
}

public fun on_demand_package_id(state: &State): ID {
    state.on_demand_package_id
}

public(package) fun set_on_demand_package_id(
    state: &mut State,
    on_demand_package_id: ID,
) {
    state.on_demand_package_id = on_demand_package_id;
}

public(package) fun set_guardian_queue_id(
    state: &mut State,
    guardian_queue_id: ID,
) {
    state.guardian_queue = guardian_queue_id;
}

public (package) fun set_oracle_queue_id(
    state: &mut State,
    oracle_queue_id: ID,
) {
    state.oracle_queue = oracle_queue_id;
}