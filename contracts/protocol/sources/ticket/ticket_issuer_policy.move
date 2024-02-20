module protocol::ticket_issuer_policy {

    use std::type_name::{Self, TypeName};
    use sui::object::UID;
    use sui::vec_set::{Self, VecSet};
    use sui::table::{Self, Table};

    friend protocol::ticket_accesses;
    
    struct TicketIssuerPolicy has key {
        id: UID,
        // ticket_type, witnesses[]
        witness_types: Table<TypeName, VecSet<TypeName>>,
    }

    public(friend) fun add_witness_type<Ticket, Witness: drop>(
        ticket_issuer_policy: &mut TicketIssuerPolicy,
    ) {
        let ticket_type = type_name::get<Ticket>();
        let witness_type = type_name::get<Witness>();

        if (table::contains(&ticket_issuer_policy.witness_types, ticket_type)) {
            table::add(&mut ticket_issuer_policy.witness_types, ticket_type, vec_set::singleton(witness_type));
        } else {
            let sets = table::borrow_mut(&mut ticket_issuer_policy.witness_types, ticket_type);
            vec_set::insert(sets, witness_type);
        };
    }

    public(friend) fun remove_witness_type<Ticket, Witness: drop>(
        ticket_issuer_policy: &mut TicketIssuerPolicy,
    ) {
        let ticket_type = type_name::get<Ticket>();
        let witness_type = type_name::get<Witness>();

        let sets = table::borrow_mut(&mut ticket_issuer_policy.witness_types, ticket_type);
        vec_set::remove(sets, &witness_type);

        if (vec_set::is_empty(sets)) {
            table::remove(&mut ticket_issuer_policy.witness_types, ticket_type);
        };
    }

    public(friend) fun is_witness_can_issue_ticket<Ticket, Witness: drop>(
        ticket_issuer_policy: &TicketIssuerPolicy,
        _: &Witness,
    ): bool {
        let ticket_type = type_name::get<Ticket>();
        let witness_type = type_name::get<Witness>();

        let sets = table::borrow(&ticket_issuer_policy.witness_types, ticket_type);
        vec_set::contains(sets, &witness_type)
    }
}