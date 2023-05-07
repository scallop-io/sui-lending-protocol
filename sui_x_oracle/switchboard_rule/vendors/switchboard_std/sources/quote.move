module switchboard_std::quote {
    use switchboard_std::utils;
    use switchboard_std::errors;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use std::hash;
    use std::bcs;

    struct Quote has key {
        id: UID,
        node_addr: address,
        node_authority: address,
        queue_addr: address,
        quote_buffer: vector<u8>,
        verification_status: u8,
        verification_timestamp: u64,
        valid_until: u64,
        content_hash_enabled: bool,
        friend_key: vector<u8>,
    }

    public fun VERIFICATION_PENDING(): u8 { 0 }
    public fun VERIFICATION_FAILURE(): u8 { 1 }
    public fun VERIFICATION_SUCCESS(): u8 { 2 }
    public fun VERIFICATION_OVERRIDE(): u8 { 3 }

    public fun new<T>(
        node: address, 
        node_authority: address, 
        queue: address, 
        quote_buffer: vector<u8>, 
        content_hash_enabled: bool,
        _friend_key: &T,
        ctx: &mut TxContext
    ): Quote {
        Quote {
            id: object::new(ctx),
            node_addr: node,
            node_authority: node_authority,
            queue_addr: queue,
            quote_buffer: quote_buffer,
            verification_status: 0,
            verification_timestamp: 0,
            valid_until: 0,
            content_hash_enabled,
            friend_key: utils::type_of<T>(),
        }
    }

    public fun verify_quote_data(quote: &Quote): (bool, vector<u8>) {
        let (mr_enclave, report_data) = utils::parse_sgx_quote(&quote.quote_buffer);
        if (!quote.content_hash_enabled) {
            assert!(hash::sha2_256(bcs::to_bytes(&quote.node_authority)) == utils::slice(&report_data, 0, 32), errors::InvalidArgument());
        };
        (quote.content_hash_enabled, mr_enclave)
    }

    public fun quote_address(quote: &Quote): address {
        object::uid_to_address(&quote.id)
    }

    public fun node_addr(quote: &Quote): address {
        quote.node_addr
    }

    public fun node_authority(quote: &Quote): address {
        quote.node_authority
    }

    public fun queue_addr(quote: &Quote): address {
        quote.queue_addr
    }

    public fun quote_buffer(quote: &Quote): &vector<u8> {
        &quote.quote_buffer
    }

    public fun verification_status(quote: &Quote): u8 {
        quote.verification_status
    }

    public fun verification_timestamp(quote: &Quote): u64 {
        quote.verification_timestamp
    }

    public fun valid_until(quote: &Quote): u64 {
        quote.valid_until
    }

    public fun is_valid(quote: &Quote, now: u64): bool {
        if (quote.verification_status == VERIFICATION_SUCCESS()) {
            return true
        };
        if (quote.verification_status == VERIFICATION_OVERRIDE()) {
            return true
        };
        if (quote.verification_status == VERIFICATION_PENDING()) {
            return false
        };
        if (quote.verification_status == VERIFICATION_FAILURE()) {
            return false
        };
        if (quote.valid_until < now) {
            return false
        };
        false
    }

    public fun share_quote(quote: Quote) {
        transfer::share_object(quote);
    }

    // Package Scoped Functions ---------------------- //
    // only available to functions for which friend_key is available

    public fun set_configs<T>(
        quote: &mut Quote, 
        node_addr: address, 
        node_authority: address, 
        queue_addr: address, 
        quote_buffer: vector<u8>, 
        verification_status: u8, 
        verification_timestamp: u64, 
        valid_until: u64,
        _friend_key: &T,
    ) {
        assert!(&quote.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        quote.node_addr = node_addr;
        quote.node_authority = node_authority;
        quote.queue_addr = queue_addr;
        quote.quote_buffer = quote_buffer;
        quote.verification_status = verification_status;
        quote.verification_timestamp = verification_timestamp;
        quote.valid_until = valid_until;
    }

    public fun force_override<T>(
        quote: &mut Quote, 
        valid_until: u64,
        now: u64,
        _friend_key: &T,
    ) {
        assert!(&quote.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        quote.verification_status = VERIFICATION_OVERRIDE();
        quote.valid_until = valid_until;
        quote.verification_timestamp = now;
    }

    public fun verify<T>(
        quote: &mut Quote, 
        valid_until: u64,
        now: u64,
        _friend_key: &T,
    ) {
        assert!(&quote.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        quote.verification_status = VERIFICATION_SUCCESS();
        quote.verification_timestamp = now;
        quote.valid_until = valid_until;
    }

    public fun fail<T>(
        quote: &mut Quote, 
        _friend_key: &T,
    ) {
        assert!(&quote.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        quote.verification_status = VERIFICATION_FAILURE();
    }
}
