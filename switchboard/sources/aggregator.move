module switchboard::aggregator {
    use switchboard::math::{Self, SwitchboardDecimal};
    use switchboard::job::{Self, Job};
    use switchboard::errors;
    use switchboard::utils;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field;
    use sui::dynamic_field;
    use sui::bag::{Self, Bag};
    use sui::coin::{Coin};
    use sui::clock::{Self, Clock};
    use std::vector;
    use std::hash;

    // [SHARED]
    struct Aggregator has key {
        id: UID,

        // Aggregator Config Data
        authority: address, 
        queue_addr: address,
        token_addr: address,
        batch_size: u64,
        min_oracle_results: u64,
        min_update_delay_seconds: u64,

        // Aggregator Optional Configs
        name: vector<u8>,
        history_limit: u64,
        variance_threshold: SwitchboardDecimal,
        force_report_period: u64,
        min_job_results: u64,
        crank_disabled: bool,
        crank_row_count: u8,

        // Aggregator State
        next_allowed_update_time: u64,

        // Created-at timestamp (seconds)
        created_at: u64,

        // Aggregator Read Configs
        read_charge: u64,
        reward_escrow: address,
        read_whitelist: Bag,
        limit_reads_to_whitelist: bool,

        // Aggregator Update Data
        update_data: SlidingWindow,

        // Interval / Payout Data
        interval_id: u64,
        curr_interval_payouts: u64,
        next_interval_refresh_time: u64,

        // Leases
        escrows: Bag,

        // Friend key to emulate (friend) behavior - users must pass in a type only accessible to friends in a package
        friend_key: vector<u8>,

        // DYNAMIC FIELDS -----
        // b"history": AggregatorHistoryData,
        // b"jobs_data": AggregatorJobData 
    }

    struct SlidingWindowElement has store, drop, copy {
        oracle_addr: address,
        value: SwitchboardDecimal,
        timestamp: u64
    }
    
    // [IMMUTABLE / SHARED] - shared within the Aggregator, immutable for the Result
    struct SlidingWindow has copy, store {
        data: vector<SlidingWindowElement>,
        latest_result: SwitchboardDecimal,
        latest_timestamp: u64,
    }

    // [SHARED]
    struct AggregatorHistoryData has key, store {
        id: UID,
        data: vector<AggregatorHistoryRow>,
        history_write_idx: u64,
    }

    struct AggregatorHistoryRow has drop, copy, store {
        value: SwitchboardDecimal,
        timestamp: u64,
    }

    // [SHARED]
    struct AggregatorJobData has key, store {
        id: UID,
        job_keys: vector<address>,
        job_weights: vector<u8>,
        jobs_checksum: vector<u8>,
    }
    
    // --- Initialization
    fun init(_ctx: &mut TxContext) {}

    public fun new<T: drop>(
        name: vector<u8>,
        queue_addr: address,
        batch_size: u64,
        min_oracle_results: u64,
        min_job_results: u64,
        min_update_delay_seconds: u64,
        variance_threshold: SwitchboardDecimal,
        force_report_period: u64,
        disable_crank: bool,
        history_limit: u64,
        read_charge: u64,
        reward_escrow: address,
        read_whitelist: vector<address>,
        limit_reads_to_whitelist: bool,
        created_at: u64,
        authority: address,
        _friend_key: &T,
        ctx: &mut TxContext
    ): Aggregator {
        let id = object::new(ctx);
        
        let history_id = object::new(ctx);
        dynamic_object_field::add(&mut id, b"history", AggregatorHistoryData {
            id: history_id,
            data: vector::empty(),
            history_write_idx: 0,
        });


        let job_data_id = object::new(ctx);
        dynamic_object_field::add(&mut id, b"job_data", AggregatorJobData {
            id: job_data_id,
            job_keys: vector::empty(),
            job_weights: vector::empty(),
            jobs_checksum: vector::empty(),
        });

        // generate read whitelist
        let readers = bag::new(ctx);
        let i = 0;
        while (i < vector::length(&read_whitelist)) {
            bag::add(&mut readers, *vector::borrow(&read_whitelist, i), true);
            i = i + 1;
        };
        
        // get friend key byte array from type - limits access to functions to package
        let friend_key = utils::type_of<T>();
        
        // emit init event
        Aggregator {
            id,
            authority, 
            queue_addr,
            batch_size,
            min_oracle_results,
            min_update_delay_seconds,
            name,
            history_limit,
            variance_threshold,
            force_report_period,
            min_job_results,
            crank_disabled: disable_crank,
            crank_row_count: 0,
            next_allowed_update_time: 0,
            read_charge,
            reward_escrow,
            read_whitelist: readers,
            limit_reads_to_whitelist,
            created_at,
            update_data: SlidingWindow {
                data: vector::empty(),
                latest_timestamp: created_at,
                latest_result: math::zero(),
            },
            interval_id: 0,
            curr_interval_payouts: 0,
            next_interval_refresh_time: created_at,
            escrows: bag::new(ctx),
            token_addr: @0x0,
            friend_key,
        }
    }

    public fun share_aggregator(aggregator: Aggregator) {
        transfer::share_object(aggregator);
    }

    public fun latest_value(aggregator: &Aggregator): (SwitchboardDecimal, u64) {
        assert!(aggregator.read_charge == 0, errors::PermissionDenied());
        (
            aggregator.update_data.latest_result, 
            aggregator.update_data.latest_timestamp,
        )
    }

    public fun batch_size(aggregator: &Aggregator): u64 {
        aggregator.batch_size
    }

    public fun min_oracle_results(aggregator: &Aggregator): u64 {
        aggregator.min_oracle_results
    }

    public fun can_open_round(aggregator: &Aggregator, now: u64): bool {
        now >= aggregator.next_allowed_update_time
    }

    public fun authority(aggregator: &Aggregator): address {
        aggregator.authority
    }

    public fun has_authority(aggregator: &Aggregator, ctx: &TxContext): bool {
        aggregator.authority == tx_context::sender(ctx)
    }

    public fun queue_address(aggregator: &Aggregator): address {
        aggregator.queue_addr
    }

    public fun is_locked(aggregator: &Aggregator): bool {
        aggregator.authority == @0x0
    }

    public fun job_keys(aggregator: &Aggregator): vector<address> {
        let job_data = dynamic_object_field::borrow<vector<u8>, AggregatorJobData>(&aggregator.id, b"job_data");
        job_data.job_keys
    }

    public fun aggregator_address(aggregator: &Aggregator): address {
        object::uid_to_address(&aggregator.id)
    }
    
    public fun crank_disabled(aggregator: &Aggregator): bool {
        aggregator.crank_disabled
    }

    public fun curr_interval_payouts(aggregator: &Aggregator): u64 {
        aggregator.curr_interval_payouts
    }

    public fun interval_id(aggregator: &Aggregator): u64 {
        aggregator.interval_id
    }

    public fun crank_row_count(aggregator: &Aggregator): u8 {
        aggregator.crank_row_count
    }

    public fun created_at(aggregator: &Aggregator): u64 {
        aggregator.created_at
    }

    public fun escrow_balance<CoinType>(
        aggregator: &Aggregator, 
        key: address
    ): u64 {
        utils::escrow_balance<CoinType>(&aggregator.escrows, key)
    }

    public fun set_authority(aggregator: &mut Aggregator, authority: address, ctx: &mut TxContext) {
        assert!(has_authority(aggregator, ctx), errors::InvalidAuthority());
        aggregator.authority = authority;
    }

    public fun set_aggregator_token(aggregator: &mut Aggregator, token_addr: address, ctx: &mut TxContext) {
        assert!(has_authority(aggregator, ctx), errors::InvalidAuthority());
        aggregator.token_addr = token_addr;
    }

    public fun add_job(aggregator: &mut Aggregator, job: &Job, weight: u8, ctx: &mut TxContext) {
        assert!(has_authority(aggregator, ctx), errors::InvalidAuthority());
        let job_data = dynamic_object_field::borrow_mut<vector<u8>, AggregatorJobData>(&mut aggregator.id, b"job_data");
        let has_job = dynamic_field::exists_with_type<address, vector<u8>>(
            &job_data.id,
            job::job_address(job)
        );
        if (!has_job) {
            dynamic_field::add(&mut job_data.id, job::job_address(job), job::hash(job));
        };
        vector::push_back(&mut job_data.job_keys, job::job_address(job));
        vector::push_back(&mut job_data.job_weights, weight);
        let checksum = vector::empty();
        let i = 0;
        while (i < vector::length(&job_data.job_keys)) {
            let job_key = vector::borrow(&job_data.job_keys, i);
            let job_hash = dynamic_field::borrow<address, vector<u8>>(&job_data.id, *job_key);
            vector::append(&mut checksum, *job_hash);
            checksum = hash::sha3_256(checksum);
            i = i + 1;
        };
        job_data.jobs_checksum = checksum;
    }

    public fun remove_job(aggregator: &mut Aggregator, job_address: address, ctx: &mut TxContext) {
        assert!(has_authority(aggregator, ctx), errors::InvalidAuthority());
        let job_data = dynamic_object_field::borrow_mut<vector<u8>, AggregatorJobData>(&mut aggregator.id, b"job_data");
        let (is_in, idx) = vector::index_of(&job_data.job_keys, &job_address);
        if (!is_in) {
            return
        };       
        vector::swap_remove(&mut job_data.job_keys, idx);
        vector::swap_remove(&mut job_data.job_weights, idx);
        let checksum = vector::empty();
        let i = 0;
        while (i < vector::length(&job_data.job_keys)) {
            let job_key = vector::borrow(&job_data.job_keys, i);
            let job_hash = dynamic_field::borrow<address, vector<u8>>(&job_data.id, *job_key);
            vector::append(&mut checksum, *job_hash);
            checksum = hash::sha3_256(checksum);
            i = i + 1;
        };
        job_data.jobs_checksum = checksum;
    }

    public fun set_config(
        aggregator: &mut Aggregator,
        name: vector<u8>,
        queue_addr: address,
        batch_size: u64,
        min_oracle_results: u64,
        min_job_results: u64,
        min_update_delay_seconds: u64,
        variance_threshold: SwitchboardDecimal,
        force_report_period: u64,
        disable_crank: bool,
        history_limit: u64,
        read_charge: u64,
        reward_escrow: address,
        read_whitelist: vector<address>,
        remove_from_whitelist: vector<address>,
        limit_reads_to_whitelist: bool,
        ctx: &mut TxContext,
    ) {
        assert!(has_authority(aggregator, ctx), errors::InvalidAuthority());
        aggregator.name = name;
        aggregator.min_job_results = min_job_results;
        aggregator.variance_threshold = variance_threshold;
        aggregator.force_report_period = force_report_period;
        aggregator.crank_disabled = disable_crank;
        aggregator.queue_addr = queue_addr;
        aggregator.batch_size = batch_size;
        aggregator.min_oracle_results = min_oracle_results;
        aggregator.min_update_delay_seconds = min_update_delay_seconds;
        aggregator.variance_threshold = variance_threshold;
        aggregator.force_report_period = force_report_period;

        // add to reader list
        let i = 0;
        while (i < vector::length(&read_whitelist)) {
            bag::add(&mut aggregator.read_whitelist, *vector::borrow(&read_whitelist, i), true);
            i = i + 1;
        };

        // remove from whitelist
        let i = 0;
        while (i < vector::length(&remove_from_whitelist)) {
            bag::remove<address, bool>(&mut aggregator.read_whitelist, *vector::borrow(&remove_from_whitelist, i));
            i = i + 1;
        };

        aggregator.read_charge = read_charge;
        aggregator.reward_escrow = reward_escrow;
        aggregator.limit_reads_to_whitelist = limit_reads_to_whitelist;
        
        // if change in history length, reset history
        if (history_limit != aggregator.history_limit) {
            let aggregator_history = dynamic_object_field::borrow_mut<vector<u8>, AggregatorHistoryData>(&mut aggregator.id, b"history");
            aggregator_history.data = vector::empty();
            aggregator_history.history_write_idx = 0;
            aggregator.history_limit = history_limit;
        };
    }

    // Some sliding window functions
    
    // make result accessible
    public fun sliding_window_latest_result(window: &SlidingWindow): (SwitchboardDecimal, u64) {
        (window.latest_result, window.latest_timestamp)
    }

    // new window
    public fun new_sliding_window(): SlidingWindow {
        SlidingWindow {
            data: vector::empty(),
            latest_result: math::zero(),
            latest_timestamp: 0,
        }
    }

    // get indices of elements older than a given age in seconds
    public fun results_older_than(window: &SlidingWindow, clock: &Clock, age_seconds: u64): bool {
        // make sure that every result is max age seconds old
        let i = 0;
        while (i < vector::length(&window.data)) {
            let time_diff = (clock::timestamp_ms(clock) / 1000) - vector::borrow(&window.data, i).timestamp;
            if (time_diff >= age_seconds) {
                return true
            };
            i = i + 1;
        };
        false
    }

    // mutate the update data 
    public fun add_to_sliding_window(
        update_data: &mut SlidingWindow,
        oracle_addr: address,
        value: SwitchboardDecimal,
        batch_size: u64,
        min_oracle_results: u64,
        now: u64,
    ): (bool, SwitchboardDecimal) {
        let batch_size = batch_size;
        let i = 0;
        let oldest_idx = 0;
        let oldest_timestamp = 0;
        while (i < vector::length(&update_data.data)) {
            let curr_update = vector::borrow(&update_data.data, i);

            // remove previous updates from this oracle
            if (curr_update.oracle_addr == oracle_addr) {
                vector::swap_remove(&mut update_data.data, i);
            } else {
                if (curr_update.timestamp < oldest_timestamp) {
                    oldest_timestamp = curr_update.timestamp;
                    oldest_idx = i;
                };
                i = i + 1;
            }
        };

        // add the update to the end of the window - should be batch size length
        vector::push_back(&mut update_data.data, SlidingWindowElement {
            oracle_addr,
            timestamp: now,
            value,
        });

        // enforce batch size - we'll only ever be 1 over maybe
        if (vector::length(&update_data.data) > batch_size) {
            vector::swap_remove(&mut update_data.data, oldest_idx); // drop oldest element
        };

        // enforce min oracle results
        let window_length = vector::length(&update_data.data);
        if (window_length < min_oracle_results) {
            return (false, update_data.latest_result)
        };

        // create a vector of the values in the window
        let medians = vector::empty();
        i = 0;
        while (i < vector::length(&update_data.data)) {
            let curr_update = vector::borrow(&update_data.data, i);
            vector::push_back(&mut medians, curr_update.value);
            i = i + 1;
        };

        // write update
        update_data.latest_result = math::median(&mut medians);
        update_data.latest_timestamp = now;

        (true, update_data.latest_result)

    }


    // Package Scoped Functions ---------------------- //
    // only available to functions for which friend_key is available

    public fun add_crank_row_count<T>(aggregator: &mut Aggregator, _friend_key: &T) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        aggregator.crank_row_count = aggregator.crank_row_count + 1;
    }

    public fun sub_crank_row_count<T>(aggregator: &mut Aggregator, _friend_key: &T) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        aggregator.crank_row_count = aggregator.crank_row_count - 1;
    }
 
    public fun increment_curr_interval_payouts<T>(aggregator: &mut Aggregator, _friend_key: &T) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        aggregator.curr_interval_payouts = aggregator.curr_interval_payouts + 1;
    }
 
    public fun next_payment_interval<T>(aggregator: &mut Aggregator, _friend_key: &T) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        aggregator.interval_id = aggregator.interval_id + 1;
        aggregator.curr_interval_payouts = 0; 
    }

    public fun escrow_deposit<CoinType, T>(
        aggregator: &mut Aggregator, 
        addr: address,
        coin: Coin<CoinType>,
        _friend_key: &T,
    ) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        utils::escrow_deposit(&mut aggregator.escrows, addr, coin);
    }

    public fun escrow_withdraw<CoinType, T>(
        aggregator: &mut Aggregator, 
        addr: address,
        amount: u64,
        _friend_key: &T,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        utils::escrow_withdraw(&mut aggregator.escrows, addr, amount, ctx)
    }

    // Returns (confirmed, result)
    public fun push_update<T>(
        aggregator: &mut Aggregator, 
        oracle_addr: address,
        value: SwitchboardDecimal,
        now: u64,
        _friend_key: &T
    ): (bool, SwitchboardDecimal) {
        assert!(&aggregator.friend_key == &utils::type_of<T>(), errors::InvalidPackage());
        let batch_size = aggregator.batch_size;
        let min_oracle_results = aggregator.min_oracle_results;

        // refresh payout interval if it's time
        if (aggregator.next_interval_refresh_time < now) {
            aggregator.interval_id = aggregator.interval_id + 1;
            aggregator.curr_interval_payouts = 0;
            aggregator.next_interval_refresh_time = now + aggregator.min_update_delay_seconds;
        };

        // add update to sliding window
        let (confirmed, result) = add_to_sliding_window(
            &mut aggregator.update_data, 
            oracle_addr, 
            value, 
            batch_size, 
            min_oracle_results,
            now,
        );

        // update history
        if (aggregator.history_limit != 0) {
            let aggregator_history = dynamic_object_field::borrow_mut<vector<u8>, AggregatorHistoryData>(&mut aggregator.id, b"history");
            if (vector::length(&aggregator_history.data) != aggregator.history_limit) {
                vector::push_back(&mut aggregator_history.data, AggregatorHistoryRow {
                    value: aggregator.update_data.latest_result,
                    timestamp: now,              
                });
            } else {
                let history_row = vector::borrow_mut(&mut aggregator_history.data, aggregator_history.history_write_idx);
                history_row.value = aggregator.update_data.latest_result;
                history_row.timestamp = now;
            };

            aggregator_history.history_write_idx = (aggregator_history.history_write_idx + 1) % aggregator.history_limit;
        };

        (confirmed, result)
    }


    #[test_only]
    struct SecretKey has drop {}

    #[test_only]
    public fun create_aggregator_for_testing(ctx: &mut TxContext): Aggregator {
        new(
            b"test", // name: 
            @0x0, // queue_addr: 
            1, // batch_size: 
            1, // min_oracle_results: 
            1, // min_job_results: 
            0, // min_update_delay_seconds: 
            math::zero(), // variance_threshold: 
            0, // force_report_period: 
            false, // disable_crank: 
            0, // history_limit: 
            0, // read_charge: 
            @0x0, // reward_escrow: 
            vector::empty(), // read_whitelist: 
            false, // limit_reads_to_whitelist: 
            0, // created_at: 
            tx_context::sender(ctx), // authority, - this is the owner of the aggregator
            &SecretKey {}, // _friend_key: scopes the function to only by the package of aggregator creator (intenrnal)
            ctx,
        )
    }

    #[test_only]
    public fun set_value_for_testing(
        value: u128,        // example the number 10 would be 10 * 10^dec (dec automatically scaled to 9)
        scale_factor: u8,   // example 9 would be 10^9, 10 = 1000000000
        negative: bool,     // example -10 would be true
        aggregator: &mut Aggregator, // aggregator
        now: u64,           // timestamp (in seconds)
        ctx: &mut TxContext
    ) {

        // set the value of a test aggregator
        push_update(
            aggregator, 
            tx_context::sender(ctx), 
            math::new(value, scale_factor, negative),
            now,
            &SecretKey {},
        );
    }

    #[test(account = @0x1)]
    public entry fun create_and_read_test_aggregator(): address {
        use sui::test_scenario;

        let admin = @0xA1;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;
        let aggregator = create_aggregator_for_testing(test_scenario::ctx(scenario));

        // set the update timestamp to 1000 (seconds)
        let now = 1000;

        // set the value of the aggregator to 10
        set_value_for_testing(10, 9, false, &mut aggregator, now, test_scenario::ctx(scenario));

        // read the latest value
        let (result, timestamp) = latest_value(&aggregator);
        let (result, scale_factor, negative) = math::unpack(result);

        // check that values are what was expected
        assert!(result == 10, errors::InvalidArgument());
        assert!(scale_factor == 9, errors::InvalidArgument());
        assert!(negative == false, errors::InvalidArgument());

        // check timestamp
        assert!(timestamp == now, errors::InvalidArgument());

        let aggregator_address = aggregator_address(&aggregator);

        // get rid of aggregator
        share_aggregator(aggregator);
        test_scenario::end(scenario_val);

        aggregator_address
    }
}
