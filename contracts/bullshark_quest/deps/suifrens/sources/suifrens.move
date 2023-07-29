// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A simple yet powerful core which allows creating new Capy
/// applications and give the power to mint once Capy Admin
/// authorized them via the common interface.
module suifrens::suifrens {
    use std::string::String;
    use std::vector;

    use sui::bcs;
    use sui::hash::blake2b256 as hash;
    use sui::tx_context::{sender, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::vec_set::{Self, VecSet};
    use sui::dynamic_field as df;
    use sui::package::{Self};
    use sui::clock::Clock;
    use sui::event::emit;
    use sui::transfer;

    /// Trying to perform an action when not authorized.
    const ENotAuthorized: u64 = 0;
    /// Does not comply to cohort limitation regarding max minting time.
    const ENotCohortTimeCompliant: u64 = 1;
    /// Does not comply to cohort limitation regarding max minting quantity.
    const ENotCohortQuantityCompliant: u64 = 2;
    /// When trying to add a country code that already exists in the vector.
    const ECountryCodeAlreadyExists: u64 = 3;
    /// When trying to remove a country code that does not exist.
    const ECountryCodeDoesNotExist: u64 = 4;
    /// When trying to mint when allowed_country_codes is empty.
    const ECountryCodesEmpty: u64 = 5;

    // ======== Types =========

    /// The `SuiFren` type - the main type of the `suifrens`
    /// package which contains all common attributes.
    struct SuiFren<phantom T> has key, store {
        id: UID,
        generation: u64,
        birthdate: u64,
        cohort: u32,
        genes: vector<u8>,
        attributes: vector<String>,
        birth_location: String,
    }

    /// Capability granting mint permission.
    struct AppCap has store, drop {
        app_name: String,
        cohort: u32,
        cohort_name: String,
        time_limit: u64,
        minting_limit: u64,
        minting_counter: u64,
        allowed_country_codes: VecSet<String>,
    }

    /// Admin Capability which allows third party applications
    /// to create new `Capy`'s
    struct AdminCap has key, store { id: UID }

    /// Custom key under which the app cap is attached.
    struct AppKey<phantom T> has copy, store, drop {}

    /// OTW to create the `Publisher`.
    struct SUIFRENS has drop {}

    //------- Events ---------------

    /// Event. When new Capy is born.
    struct SuiFrenMinted has copy, drop {
        id: ID,
        app_name: String,
        generation: u64,
        cohort: u32,
        genes: vector<u8>,
        attributes: vector<String>,
        birth_location: String,
        birthdate: u64,
        created_by: address,
    }

    /// Module initializer. Uses One Time Witness to create Publisher and transfer it to sender
    fun init(otw: SUIFRENS, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);
        transfer::transfer(AdminCap { id: object::new(ctx) }, sender(ctx));
    }

    /// Mint a new SuiFren. Can only be performed by an authorized application,
    /// and only if the `AppCap` passes the checks on limits, time and a country
    /// code.
    ///
    /// Can never be called directly and is
    public fun mint<T>(
        app: &mut UID,
        generation: u64,
        genes: vector<u8>,
        attributes: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ): SuiFren<T> {
        assert!(is_authorized<T>(app), ENotAuthorized);

        let app_cap = app_cap_mut<T>(app);

        // Check for compliance to cohort rules
        assert!((sui::clock::timestamp_ms(clock) <= app_cap.time_limit), ENotCohortTimeCompliant);
        assert!((app_cap.minting_counter < app_cap.minting_limit), ENotCohortQuantityCompliant);

        // Check if allowed_country_codes is empty
        // Check if `birth_location` is in allowed_country_codes
        assert!(!vec_set::is_empty(&app_cap.allowed_country_codes), ECountryCodesEmpty);

        // Important: We get the app_cap to increase the minting counter and pass cohort to mint event
        app_cap.minting_counter = app_cap.minting_counter + 1;

        let id = object::new(ctx);
        let birthdate = sui::clock::timestamp_ms(clock);

        // We are rehashing genes along with &id to get a new beacon. Even if two NFTs share the same genes,
        // their IDs will be different, so we achieve beacon uniqueness.
        let beacon = hash(&bcs::to_bytes(&vector[
            bcs::to_bytes(&id),
            bcs::to_bytes(&genes),
            bcs::to_bytes(&birthdate)
        ]));

        let birth_location = get_birth_location(app_cap, beacon);

        emit(SuiFrenMinted {
            id: object::uid_to_inner(&id),
            app_name: app_cap.app_name,
            generation,
            cohort: app_cap.cohort,
            attributes,
            genes,
            birth_location,
            birthdate,
            created_by: sender(ctx)
        });

        SuiFren {
            id,
            generation,
            cohort: app_cap.cohort,
            birthdate,
            genes,
            attributes,
            birth_location,
        }
    }

    /// Unpack the `SuiFren` object and return UID for dynamic fields processing.
    public fun burn<T>(app: &mut UID, suifren: SuiFren<T>): UID {
        assert!(is_authorized<T>(app), ENotAuthorized);
        let SuiFren {
            id,
            generation: _,
            cohort: _,
            birthdate: _,
            genes: _,
            attributes: _,
            birth_location: _
        } = suifren;
        id
    }

    // === Authorization ===

    /// Attach an `AppCap` under an `AppKey` to grant an application access
    /// to minting and burning.
    public fun authorize_app<T>(
        _: &AdminCap,
        app: &mut UID,
        app_name: String,
        cohort_num: u32,
        cohort_name: String,
        time_limit: u64,
        minting_limit: u64,
        allowed_country_codes: vector<String>,
    ) {
        df::add(app, AppKey<T> {},
            AppCap {
                cohort: cohort_num,
                app_name,
                cohort_name,
                time_limit,
                minting_limit,
                minting_counter: 0,
                allowed_country_codes: vec_to_set(allowed_country_codes)
            }
        )
    }

    /// Detach the `AppCap` from the application to revoke access.
    public fun revoke_auth<T>(_: &AdminCap, app: &mut UID) {
        let AppCap {
            app_name: _,
            cohort: _,
            cohort_name: _,
            time_limit: _,
            minting_limit: _,
            minting_counter: _,
            allowed_country_codes: _
        } = df::remove(app, AppKey<T> {});
    }

    /// Check whether an Application has a permission to mint or
    /// burn a specific SuiFren<T>.
    public fun is_authorized<T>(app: &UID): bool {
        df::exists_<AppKey<T>>(app, AppKey {})
    }

    /// Add a country code
    public fun add_country_code<T>(
        _: &AdminCap,
        app: &mut UID,
        country_code: String,
    ) {
        let app_cap = app_cap_mut<T>(app);
        assert!(!vec_set::contains(&app_cap.allowed_country_codes, &country_code), ECountryCodeAlreadyExists);
        vec_set::insert(&mut app_cap.allowed_country_codes, country_code);
    }

    /// Remove a country code from the application.
    public fun remove_country_code<T>(
        _: &AdminCap,
        app: &mut UID,
        country_code: String,
    ) {
        let app_cap = app_cap_mut<T>(app);
        assert!(vec_set::contains(&app_cap.allowed_country_codes, &country_code), ECountryCodeDoesNotExist);
        vec_set::remove(&mut app_cap.allowed_country_codes, &country_code)
    }

    /// === UID Access ===

    /// SuiFren UID to allow reading dynamic fields.
    public fun uid<T>(fren: &SuiFren<T>): &UID { &fren.id }

    /// Expose mutable access to the SuiFren `UID` to allow extensions.
    public fun uid_mut<T>(fren: &mut SuiFren<T>): &mut UID { &mut fren.id }

    /// === SuiFren Fields ===

    /// Accessor for the `genes` field of a `SuiFren`.
    public fun genes<T>(self: &SuiFren<T>): &vector<u8> { &self.genes }

    /// Read the `cohort` field from the `SuiFren`.
    public fun cohort<T>(self: &SuiFren<T>): u32 { self.cohort }

    /// Accessor for the `generation` field of a `SuiFren`.
    public fun generation<T>(self: &SuiFren<T>): u64 { self.generation }

    /// Accessor for the `birthdate` of a `SuiFren`. Timestamp in milliseconds.
    public fun birthdate<T>(self: &SuiFren<T>): u64 { self.birthdate }

    /// Accessor for the birth location of a SuiFren
    public fun birth_location<T>(self: &SuiFren<T>): String { self.birth_location }

    /// Get the reference to the `attributes` field of the `SuiFren`.
    public fun attributes<T>(self: &SuiFren<T>): &vector<String> { &self.attributes }

    // === Internal ===

    /// Returns the `AppCap` that provides information about cohort.
    fun app_cap_mut<T>(app: &mut UID): &mut AppCap {
        df::borrow_mut<AppKey<T>, AppCap>(app, AppKey {})
    }

    /// Internal: turn a `vector` into a `VecSet`.
    fun vec_to_set<T: store + copy + drop>(v: vector<T>): VecSet<T> {
        let vec_set = vec_set::empty();
        while (vector::length(&v) > 0) {
            vec_set::insert(&mut vec_set, vector::pop_back(&mut v));
        };
        vec_set
    }

    /// Internal: choose a random birth location from the allowed_country_codes
    fun get_birth_location(app_cap: &AppCap, beacon: vector<u8>): String {
        // We use the first 16 bytes of the beacon as a u128, then mod num-of-countries
        // to reduce bias.
        let country_codes = vec_set::into_keys(*&app_cap.allowed_country_codes);
        let country_position = (*vector::borrow(&beacon, 0) as u128);
        let i = 1;
        while (i < 16) {
            country_position = (country_position << 8) + (*vector::borrow(&beacon, i) as u128);
            i = i + 1;
        };
        country_position = country_position % (vector::length(&country_codes) as u128);
        *vector::borrow(&country_codes, (country_position as u64))
    }

    // === Test functions ===

    #[test_only]
    public fun mint_for_testing<T>(ctx: &mut TxContext): SuiFren<T> {
        let id = object::new(ctx);
        let hash = std::hash::sha3_256(bcs::to_bytes(&id));
        SuiFren {
            id,
            generation: 0,
            cohort: 0,
            birthdate: 0,
            genes: hash,
            attributes: vector[],
            birth_location: std::string::utf8(b"KAY"),
        }
    }

    #[test_only]
    public fun burn_for_testing<T>(suifren: SuiFren<T>) {
        let SuiFren {
            id,
            generation: _,
            cohort: _,
            birthdate: _,
            genes: _,
            attributes: _,
            birth_location: _,
        } = suifren;
        object::delete(id)
    }

    #[test_only]
    public fun test_new_admin_cap(ctx: &mut TxContext): AdminCap {
        AdminCap { id: object::new(ctx) }
    }

    #[test_only]
    public fun test_destroy_admin_cap(cap: AdminCap) {
        let AdminCap { id } = cap;
        object::delete(id)
    }
}
