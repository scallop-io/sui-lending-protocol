// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0


/// Follows the principle "one module - one feature".
///
/// Carefully guarded access to UID gives Capy Admin a unique way
/// to authorize and deauthorize the application. Applications
/// mustn't publicly open their `UID`'s - this would lead to a breach
/// in the breeding functionality.
///
/// Mints only `suifrens::capy::Capy`
module suifrens::genesis {
    use std::string::{utf8, String};
    use sui::hash::blake2b256 as hash;
    use sui::tx_context::{fresh_object_address, TxContext};
    use sui::balance::{Self,Balance};
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::clock::Clock;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::bcs;

    // Package dependencies
    use suifrens::suifrens::{Self, AdminCap, SuiFren};
    use suifrens::genes;

    /// The amount paid does not match the expected.
    const EAmountIncorrect: u64 = 0;
    /// For when there's no profits to claim.
    const ENoProfits: u64 = 1;
    /// Trying to perform an action when not authorized.
    const EMintNotAuthorized: u64 = 2;

    /// Default fee for minting
    const DEFAULT_MINTING_PRICE: u64 = 8_000_000_000;
    /// Limits how much times a SuiFren can be mixed
    const DEFAULT_MIXING_LIMIT: u8 = 5;

    /// Mint a SuiFren App.
    struct Mint has key, store {
        id: UID,
        /// The fee that user has to pay for minting. Can be changed through method that requires admin capability
        minting_price: u64,
        /// The hash stored in the object to provide a seed for minting.
        inner_hash: vector<u8>,
        /// Mixing limit set per SuiFren on the first mix event.
        mixing_limit: u8,
        /// The profits collected from mixes
        profits: Balance<SUI>
    }

    fun init(ctx: &mut TxContext) {
        let id = object::new(ctx);
        transfer::share_object(Mint {
            inner_hash: hash(&object::uid_to_bytes(&id)),
            minting_price: DEFAULT_MINTING_PRICE,
            mixing_limit: DEFAULT_MIXING_LIMIT,
            profits: balance::zero<SUI>(),
            id,
        });
    }

    /// Main public entry fun of this example - main user facing feature.
    /// Accepts basic fren features and a coin for payment and returns a minted fren.
    /// SuiFren attribute selection is done by random genes that are generated from
    /// Actual minting is delegated to suifrens::mint
    public fun mint<T>(
        self: &mut Mint,
        clock: &Clock,
        paid: &mut Coin<SUI>,
        ctx: &mut TxContext
    ): SuiFren<T> {
        assert!(suifrens::is_authorized<T>(&self.id), EMintNotAuthorized);

        handle_payment(self, paid, ctx);

        // Create seed based on multiple sources: clock, fresh uid and an inner hash.
        let seed = hash(&bcs::to_bytes(&vector[
            self.inner_hash,
            bcs::to_bytes(&fresh_object_address(ctx)),
            bcs::to_bytes(clock)
        ]));

        let attributes = genes::get_attributes<T>(&self.id, &seed);
        self.inner_hash = seed;

        suifrens::mint<T>(&mut self.id, 0, seed, attributes, clock, ctx)
    }

    /// Private function for handling coins received from mixing payments.
    /// It breaks flow with an exception message if the payment coin does not cover the price
    fun handle_payment(self: &mut Mint, paid: &mut Coin<SUI>, ctx: &mut TxContext){
        let price = self.minting_price;
        assert!(price <= coin::value(paid), EAmountIncorrect);

        let payment_coin = coin::split(paid, price, ctx);
        coin::put(&mut self.profits, payment_coin);
    }

    /// Must-have function available for the Capy Admin to call.
    public fun authorize<T>(
        admin_cap: &AdminCap,
        self: &mut Mint,
        cohort_num: u32,
        cohort_name: String,
        time_limit: u64,
        minting_limit: u64,
        country_codes: vector<String>,
    ) {
        suifrens::authorize_app<T>(
            admin_cap,
            &mut self.id,
            utf8(b"genesis"),
            cohort_num,
            cohort_name,
            time_limit,
            minting_limit,
            country_codes
        )
    }

    /// Must-have function always available for the Capy Admin to call.
    public fun deauthorize<T>(admin_cap: &AdminCap, self: &mut Mint) {
        suifrens::revoke_auth<T>(admin_cap, &mut self.id)
    }

    /// Add a country code
    public fun add_country_code<T>(
        _: &AdminCap,
        self: &mut Mint,
        country_code: String,
    ) {
        suifrens::add_country_code<T>(_, &mut self.id, country_code);
    }

    /// Remove a country code
    public fun remove_country_code<T>(
        _: &AdminCap,
        self: &mut Mint,
        country_code: String,
    ) {
        suifrens::remove_country_code<T>(_, &mut self.id, country_code)
    }

    /// Registers gene definitions for the Genesis App.
    public fun add_genes<T>(_: &AdminCap, self: &mut Mint,  genes_bcs: vector<u8>) {
        genes::add_gene_definitions<T>(&mut self.id, genes_bcs)
    }

    /// Guarded extendability function to allow any further extensions without package
    /// upgrades (an Admin can attach new extensions without extra effort).
    public fun uid_mut(_: &AdminCap, self: &mut Mint): &mut UID {
        &mut self.id
    }

    /// Modifies the minting price. Requires Admin Capabilities
    public fun set_minting_price(_: &AdminCap, self: &mut Mint, new_minting_price: u64) {
        self.minting_price = new_minting_price
    }

    /// Returns the minting price currently defined in the Mint App
    public fun get_minting_price(self: &Mint ) : u64 {
        self.minting_price
    }

    /// Withdraw profits from the App as a single Coin
    /// Uses sender of transaction to determine storage and control access.
    public fun take_profits(_: &AdminCap, self: &mut Mint, ctx: &mut TxContext) : Coin<SUI>  {
        let amount = balance::value(&self.profits);
        assert!(amount > 0, ENoProfits);
        // Take a transferable `Coin` from a `Balance`
        coin::take(&mut self.profits, amount, ctx)
    }

    /// Modifies the minting limit. Requires Admin Capabilities
    public fun update_mixing_limit(_: &AdminCap, self: &mut Mint, new_mixing_limit: u8) {
        self.mixing_limit = new_mixing_limit;
    }
    // === Functions for Test setup ===

    #[test_only] use suifrens::capy::Capy;

    #[test_only]
    public fun destroy_capy(self: &mut Mint, capy: SuiFren<Capy>) {
        object::delete(suifrens::burn<Capy>(&mut self.id, capy));
    }

    #[test_only]
    public fun create_app(ctx: &mut TxContext): Mint {
        let id = object::new(ctx);
        Mint {
            inner_hash: hash(&object::uid_to_bytes(&id)),
            id,
            minting_price: DEFAULT_MINTING_PRICE,
            mixing_limit: DEFAULT_MIXING_LIMIT,
            profits: balance::zero<SUI>()
        }
    }

    #[test_only]
    public fun close_app(self: Mint) {
        let Mint { id, profits, minting_price: _, inner_hash: _, mixing_limit: _ } = self;
        object::delete(id);
        balance::destroy_for_testing(profits);
    }

    #[test_only]
    public fun get_app_id(self: &mut Mint): &mut UID {
        &mut self.id
    }
}
