// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Capy labs application.
module suifrens::capy_labs {
    use std::string::{utf8, String};
    use std::option::{Self, Option};
    use std::vector as vec;

    use sui::tx_context::{Self, fresh_object_address, TxContext};
    use sui::hash::blake2b256 as hash;
    use sui::object::{Self, UID};
    use sui::balance::{Self,Balance};
    use sui::coin::{Self,Coin};
    use sui::dynamic_field as df;
    use sui::clock::Clock;
    use sui::sui::SUI;
    use sui::transfer;
    use sui::math;
    use sui::bcs;

    use suifrens::suifrens::{Self as sf, AdminCap, SuiFren};
    use suifrens::genes;

    /// Trying to perform an action when not authorized.
    const ECapyLabsNotAuthorized: u64 = 0;
    /// Trying to mix, when mix limit has been reached.
    const EReachedMixingLimit: u64 = 1;
    /// Trying to mix, when cool down period still exists
    const EStillInCoolDownPeriod: u64 = 2;
    /// The amount paid does not match the expected.
    const EAmountIncorrect: u64 = 3;
    /// For when there's no profits to claim.
    const ENoMixingProfits: u64 = 4;
    /// When ask to generate genes that are not equal to 32, the length of the sha3_256.
    const EGenesLength: u64 = 5;

    // ------------- Constants ----------------------------------

    /// Number of meaningful genes. Also marks the length
    /// of the hash used in the application: blake2b256.
    /// Currently on the first 5 {EGenesLength} are used for: skin, main, secondary, expression, and ears.
    /// But we mutate them until we enable them in the application logic.
    const GENES: u64 = 32;

    /// According to business rules, in the mix process, during gene computation there is a 40% propability to
    /// get a Gene from Parent A, a 40% probability to get a Gene from Parent B and 20% prob to get a common trait.
    /// Gene keys (selectors) are distributed in the area of 0-255.
    /// The 40% of 256 = 102. That's how the threshold is computed.
    const PARENT_A_SELECTOR_THRESHOLD: u8 = 102;
    const PARENT_B_SELECTOR_THRESHOLD: u8 = 205;

    /// There is a breeding cool down, which is the amount of time a
    /// SuiFren needs to wait until it can breed again.
    /// To start with, this value will be 1 epoch.
    const DEFAULT_COOL_DOWN_PERIOD_IN_EPOCHS: u64 = 1;

    /// Limits how much times a SuiFren can be mixed
    const DEFAULT_MIXING_LIMIT: u8 = 5;

    /// Default fee for mixing
    const DEFAULT_MIXING_PRICE: u64 = 10_000_000_000;

    /// Every capybara is registered here. Acts as a source of randomness
    /// as well as the storage for the main information about the gamestate.
    struct CapyLabsApp has key {
        id: UID,
        /// Updated every time a new SuiFren is minted. Used to provide a source
        /// of entropy for the gene science algorithm.
        inner_hash: vector<u8>,
        /// Mixing limit set per SuiFren on the first mix event.
        mixing_limit: u8,
        /// SuiFrens can be mixed with constrained frequency. If a mix happens,
        /// then a number of epochs = cool_down_period should pass for the next
        /// generation to be allowed.
        cool_down_period: u64,
        /// The fee that user has to pay for mixing. Can be changed through method
        /// that requires an admin capability.
        mixing_price: u64,
        /// The profits collected by the application. Can only be claimed by the
        /// SF Admin.
        profits: Balance<SUI>
    }

    /// Dynamic field Key: Stores the mixing limit. Can be used and read by
    /// other applications.
    struct MixLimitKey has copy, store, drop {}
    /// Dynamic field Key: Stores the last epoch a SuiFren was mixed.
    /// Can be used and read by other applications.
    struct LastEpochMixedKey has copy, store, drop {}
    /// Dynamic field Key: Stores vector of parents (usually two :))
    struct ParentsKey has copy, store, drop {}

    /// Initialize the application by creating and sharing the CapyLabsApp object.
    /// Authorization of the application needs to be performed dynamically by the
    /// SF Admin.
    fun init(ctx: &mut TxContext) {
        let id = object::new(ctx);
        let inner_hash = hash(&object::uid_to_bytes(&id));
        let app = CapyLabsApp {
            id,
            inner_hash,
            mixing_limit: DEFAULT_MIXING_LIMIT,
            cool_down_period: DEFAULT_COOL_DOWN_PERIOD_IN_EPOCHS,
            mixing_price : DEFAULT_MIXING_PRICE,
            profits: balance::zero<SUI>()
        };

        transfer::share_object(app)
    }

    /// Mix two `SuiFren`s. The resulting cutie has a mix of the
    public fun mix<T>(
        self: &mut CapyLabsApp,
        sf1: &mut SuiFren<T>,
        sf2: &mut SuiFren<T>,
        clock: &Clock,
        paid: &mut Coin<SUI>,
        ctx: &mut TxContext
    ): SuiFren<T> {
        assert!(sf::is_authorized<T>(&self.id), ECapyLabsNotAuthorized);
        handle_payment(self, paid, ctx);

        let current_epoch = tx_context::epoch(ctx);

        // Deal with Cool Down Period Business Rules
        {
            let sf1_last_epoch_mixed = last_epoch_mixed(sf1);
            if (option::is_some(&sf1_last_epoch_mixed)) {
                let last_epoch_mixed_1 = *option::borrow(&sf1_last_epoch_mixed);
                let epochs_passed_1 = current_epoch - last_epoch_mixed_1;
                assert!(epochs_passed_1 >= self.cool_down_period, EStillInCoolDownPeriod)
            };

            let sf2_last_epoch_mixed = last_epoch_mixed(sf2);
            if (option::is_some(&sf2_last_epoch_mixed)) {
                let last_epoch_mixed_2 = *option::borrow(&sf2_last_epoch_mixed);
                let epochs_passed_2 = current_epoch - last_epoch_mixed_2;
                assert!(epochs_passed_2 >= self.cool_down_period, EStillInCoolDownPeriod)
            };

            set_last_epoch_mixed(sf1, current_epoch);
            set_last_epoch_mixed(sf2, current_epoch);
        };

        // Decrease Remaining Mixes by 1.
        {
            let limit1 = mixing_limit(sf1);
            let limit2 = mixing_limit(sf2);

            if (option::is_none(&limit1)) {
                set_limit(sf1, self.mixing_limit - 1);
            } else {
                let limit = *option::borrow(&limit1);
                assert!(limit > 0, EReachedMixingLimit);
                set_limit(sf1, limit - 1);
            };

            if (option::is_none(&limit2)) {
                set_limit(sf2, self.mixing_limit - 1);
            } else {
                let limit = *option::borrow(&limit2);
                assert!(limit > 0, EReachedMixingLimit);
                set_limit(sf2, limit - 1);
            };
        };

        // Create seed based on multiple sources: clock, fresh uid and an inner hash.
        let seed = hash(&bcs::to_bytes(&vector[
            self.inner_hash,
            bcs::to_bytes(&fresh_object_address(ctx)),
            bcs::to_bytes(clock)
        ]));

        let genes = compute_genes(&seed, sf::genes(sf1), sf::genes(sf2), GENES);
        let new_generation = 1 + math::max(
            sf::generation(sf1),
            sf::generation(sf2)
        );

        let attributes = genes::get_attributes<T>(&self.id, &genes);

        let suifren = sf::mint<T>(&mut self.id, new_generation, genes, attributes, clock, ctx);
        let parents = vector[object::id(sf1), object::id(sf2)];

        // Add parents as DFs
        df::add(
            sf::uid_mut(&mut suifren),
            ParentsKey {},
            parents
        );

        // don't forget to bump the inner hash!
        // and update inner fields!
        self.inner_hash = seed;
        suifren
    }

    /// Private function for handling coins received from mixing payments.
    /// It breaks flow with an exception message if the payment coin does not cover the price.
    fun handle_payment(self: &mut CapyLabsApp, paid: &mut Coin<SUI>, ctx: &mut TxContext){
        let price = self.mixing_price;
        assert!(coin::value(paid) >= price, EAmountIncorrect);
        let payment_coin = coin::split(paid, price, ctx);
        coin::put(&mut self.profits, payment_coin);
    }

    // === App-specific Properties ===

    /// Private: get or set limit if it's not set.
    fun set_limit<T>(sf: &mut SuiFren<T>, value: u8) {
        let uid = sf::uid_mut(sf);
        let key = MixLimitKey {};

        if (df::exists_(uid, key)) {
            let _: u8 = df::remove(uid, key);
        };

        df::add(uid, key, value)
    }

    /// External accessor for property defined in this application.
    public fun mixing_limit<T>(sf: &SuiFren<T>): Option<u8> {
        let uid = sf::uid(sf);
        let key = MixLimitKey {};

        if (df::exists_(uid, key)) {
            option::some(*df::borrow(uid, key))
        } else {
            option::none()
        }
    }

    /// Private: get or set last epoch mixed.
    fun set_last_epoch_mixed<T>(sf: &mut SuiFren<T>, value: u64) {
        let uid = sf::uid_mut(sf);
        let key = LastEpochMixedKey {};

        if (df::exists_(uid, key)) {
            let _: u64 = df::remove<LastEpochMixedKey, u64>(uid, key);
        };

        df::add(uid, key, value);
    }

    /// External accessor for property defined in this application.
    public fun last_epoch_mixed<T>(sf: &SuiFren<T>): Option<u64> {
        let uid = sf::uid(sf);
        let key = LastEpochMixedKey {};

        if (df::exists_(uid, key)) {
            option::some(*df::borrow(uid, key))
        } else {
            option::none()
        }
    }

    // === Admin Functions ===

    /// Withdraw profits from the App as a single Coin (accumulated as a DOF).
    /// Uses sender of transaction to determine storage and control access.
    public fun take_profits(
        _: &AdminCap, self: &mut CapyLabsApp, ctx: &mut TxContext
    ): Coin<SUI>  {
        let amount = balance::value(&self.profits);
        assert!(amount > 0, ENoMixingProfits);
        // Take a transferable `Coin` from a `Balance`
        coin::take(&mut self.profits, amount, ctx)
    }

    /// Authorize the app to mint new SuiFrens. Can only be performed by the SF Admin.
    public fun authorize<T>(
        admin_cap: &AdminCap,
        self: &mut CapyLabsApp,
        cohort_num: u32,
        cohort_name: String,
        time_limit: u64,
        minting_limit: u64,
        country_codes: vector<String>,
    ) {
        sf::authorize_app<T>(
            admin_cap,
            &mut self.id,
            utf8(b"capy_labs"),
            cohort_num,
            cohort_name,
            time_limit,
            minting_limit,
            country_codes
        )
    }

    /// Deauthorize the app to mint new SuiFrens. Can only be performed by the SF Admin.
    /// Function can not be removed by package upgrades, hence SF Admin will always have
    /// an option to disable the application and stop minting new SuiFrens.
    public fun deauthorize<T>(admin_cap: &AdminCap, self: &mut CapyLabsApp) {
        sf::revoke_auth<T>(admin_cap, &mut self.id)
    }

    /// Add a country code.
    public fun add_country_code<T>(
        _: &AdminCap,
        self: &mut CapyLabsApp,
        country_code: String,
    ) {
        sf::add_country_code<T>(_, &mut self.id, country_code);
    }

    /// Remove a country code.
    public fun remove_country_code<T>(
        _: &AdminCap,
        self: &mut CapyLabsApp,
        country_code: String,
    ) {
        sf::remove_country_code<T>(_, &mut self.id, country_code)
    }

    /// Registers gene definitions for the CapyLabs App (and a specific type of SF).
    public fun add_genes<T>(_: &AdminCap, self: &mut CapyLabsApp, genes_bcs: vector<u8>) {
        genes::add_gene_definitions<T>(&mut self.id, genes_bcs)
    }

    /// Modifier for the `mixing_price` field of the App.
    public fun set_mixing_price(_: &AdminCap, self: &mut CapyLabsApp, new_mixing_price: u64) {
        self.mixing_price = new_mixing_price
    }

    /// Modifier for `cool_down_period` field of the App.
    public fun set_cooldown_period( _: &AdminCap, self: &mut CapyLabsApp, new_cooldown_period: u64) {
        self.cool_down_period = new_cooldown_period
    }

    /// Modifier for `mixing_limit` field of the App.
    public fun set_mixing_limit( _: &AdminCap, self: &mut CapyLabsApp, new_mixing_limit: u8) {
        self.mixing_limit = new_mixing_limit
    }

    // === Getters for the Application config ===

    /// Get the `mixing_price` for the App.
    public fun get_mixing_price(self: &CapyLabsApp): u64 { self.mixing_price }

    /// Get the `cool_down_period` for the App.
    public fun get_cooldown_period(self: &CapyLabsApp): u64 { self.cool_down_period }

    /// Get the `mixing_limit` for the App.
    public fun get_mixing_limit(self: &CapyLabsApp ): u8 { self.mixing_limit }

    /// === Utilities ===

    /// Derive something from the seed. Add a derivation path as u8, and
    /// hash the result.
    public fun derive(r0: &vector<u8>, path: u8): vector<u8> {
        let r1 = *r0;
        vec::push_back(&mut r1, path);
        hash(&r1)
    }

    /// Computes genes for the newborn based on the random seed r0, and parents genes.
    /// The `max` parameter affects how many genes should be changed (if there are no
    /// attributes yet for the).
    fun compute_genes(
        r0: &vector<u8>,
        genes1: &vector<u8>,
        genes2: &vector<u8>,
        max: u64
    ): vector<u8> {
        // Blake2b-256 returns 32 bytes. Check the value of max, to protect against accidental overflowed invocation
        assert!(((0 < max) && (max <= GENES)), EGenesLength);

        let i = 0;

        let s1 = genes1;
        let s2 = genes2;
        let s3 = vec::empty();

        let r1 = derive(r0, 1); // for parent gene selection
        let common = derive(r0, 2); // for deriving common traits

        while (i < max) {
            let rng = *vec::borrow(&r1, i);
            // If the value of rng is less or equal to 102 - `PARENT_A_SELECTOR_THRESHOLD` then the genes from `PARENT_A` are selected.
            // If the value of rng is greater than 102 and less or equal to 205 - `PARENT_B_SELECTOR_THRESHOLD`
            // then the genes from `PARENT_B` are selected.
            let gene = if (rng <= PARENT_A_SELECTOR_THRESHOLD) {
                *vec::borrow(s1, i)
            } else if (rng <= PARENT_B_SELECTOR_THRESHOLD) {
                *vec::borrow(s2, i)
            } else {
                // Common traits are 70% of traits so in the space (0-255) they are distributed in (0-179).
                // 178 =~ 69,5% of 256, Therefore we need to normalize in this space.
                let num  = *vec::borrow(&common, i);
                let restricted_num : u16 = (num as u16) * 70u16 /100u16;
                (restricted_num as u8)
            };
            vec::push_back(&mut s3, gene);
            i = i + 1;
        };

        s3
    }

    // === Test functions ===

    #[test_only]
    public fun uid_for_testing(app: &CapyLabsApp): &UID {
        &app.id
    }

    #[test_only]
    public fun get_seed_for_test(ctx: &mut TxContext) : vector<u8>{
        let id = object::new(ctx);
        let seed = hash(&bcs::to_bytes(&vector[
            object::id_to_bytes(&object::uid_to_inner(&id)),
        ]));
        object::delete(id);
        seed
    }

    #[test_only]
    public fun create_app(ctx: &mut TxContext): CapyLabsApp {
        let id = object::new(ctx);
        let app = CapyLabsApp {
            id: object::new(ctx),
            inner_hash: hash(&object::id_to_bytes(&object::uid_to_inner(&id))),
            cool_down_period: DEFAULT_COOL_DOWN_PERIOD_IN_EPOCHS,
            mixing_limit: DEFAULT_MIXING_LIMIT,
            mixing_price : DEFAULT_MIXING_PRICE,
            profits: balance::zero<SUI>()
        };
        object::delete(id);
        app
    }

    #[test_only]
    public fun close_app(self: CapyLabsApp) {
        let CapyLabsApp {
            id: _id, inner_hash: _, cool_down_period: _, mixing_limit: _, mixing_price: _, profits: p
        } = self;
        object::delete(_id);
        balance::destroy_for_testing(p);
    }
}
