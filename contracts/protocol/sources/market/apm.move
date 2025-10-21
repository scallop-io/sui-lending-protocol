module protocol::apm {
    use std::vector;
    use std::type_name::{Self, TypeName};
    use sui::dynamic_field as df;
    use x_oracle::x_oracle::XOracle;
    use decimal::decimal::{Self, Decimal};
    use protocol::price::get_price;
    use protocol::market::{Self, Market};
    use sui::clock::{Self, Clock};
    use protocol::market_dynamic_keys::{min_price_history_key, apm_threshold_key, MinPriceHistoryKey, ApmThresholdKey};

    friend protocol::borrow;
    friend protocol::obligation;
    friend protocol::app;

    struct MinPriceHistory has copy, drop, store {
        price: Decimal,
        last_update: u64,
    }

    public(friend) fun set_apm_threshold(market: &mut Market, type_name: TypeName, apm_threshold_percentage: u64) {
        init_if_not_exists(market, type_name);

        if (df::exists_(market::uid(market), apm_threshold_key(type_name))) {
            let apm_threshold = df::borrow_mut<ApmThresholdKey, Decimal>(
                market::uid_mut(market),
                apm_threshold_key(type_name),
            );
            *apm_threshold = decimal::from_percent_u64(apm_threshold_percentage);
        } else {
            df::add<ApmThresholdKey, Decimal>(
                market::uid_mut(market),
                apm_threshold_key(type_name),
                decimal::from_percent_u64(apm_threshold_percentage),
            );
        };
    }

    public(friend) fun is_price_fluctuate(
        market: &Market,
        x_oracle: &XOracle,
        type_name: TypeName,
        clock: &Clock,
    ): bool {
        let vect = df::borrow<MinPriceHistoryKey, vector<MinPriceHistory>>(market::uid(market), min_price_history_key(type_name));
        let min_price_in_24h = decimal::from(0);

        let now = clock::timestamp_ms(clock) / 1000;
        let curr_index = (now / 3600) % 24; // hourly index

        let i = 0;
        while (i < 24) {
            let min_price_history = vector::borrow(vect, i);
            
            // only consider the last 24h data
            if (now - min_price_history.last_update <= 24 * 3600) {
                if (decimal::eq(min_price_in_24h, decimal::from(0))) {
                    min_price_in_24h = min_price_history.price;
                } else if (decimal::gt(min_price_history.price, decimal::from(0))) {
                    min_price_in_24h = decimal::min(min_price_in_24h, min_price_history.price);
                };
            };

            i = i + 1;
        };

        let current_price = decimal::from_fixed_point32(get_price(x_oracle, type_name, clock));

        // check if price goes down, then skip
        if (decimal::le(current_price, min_price_in_24h)) {
            return false
        };

        if (decimal::eq(min_price_in_24h, decimal::from(0))) {
            return false
        };

        let price_increased_percentage = decimal::div(
            decimal::sub(current_price, min_price_in_24h),
            min_price_in_24h
        );

        let apm_threshold = df::borrow<ApmThresholdKey, Decimal>(market::uid(market), apm_threshold_key(type_name));
        if (decimal::ge(price_increased_percentage, *apm_threshold)) {
            return true
        };

        false
    }

    public(friend) fun record_min_price_history(
        market: &mut Market,
        x_oracle: &XOracle,
        type_name: TypeName,
        clock: &Clock,
    ) {    
        let now = clock::timestamp_ms(clock) / 1000;

        let curr_index = (now / 3600) % 24; // hourly index
        let vect = df::borrow_mut<MinPriceHistoryKey, vector<MinPriceHistory>>(market::uid_mut(market), min_price_history_key(type_name));

        let current_price = get_price(x_oracle, type_name, clock);
        let min_price_history = vector::borrow_mut(vect, curr_index);
        if (min_price_history.last_update == 0 || (now - min_price_history.last_update) > 3600) {
            // reset if it's the first time or more than an hour has passed
            min_price_history.price = decimal::from_fixed_point32(current_price);
        } else {
            min_price_history.price = decimal::min(
                min_price_history.price,
                decimal::from_fixed_point32(current_price)
            );
        };

        min_price_history.last_update = now;
    }

    fun init_if_not_exists(
        market: &mut Market,
        type_name: TypeName,
    ) {
        if (df::exists_(market::uid(market), min_price_history_key(type_name))) {
            return;
        };

        df::add<MinPriceHistoryKey, vector<MinPriceHistory>>(
            market::uid_mut(market),
            min_price_history_key(type_name),
            create_min_price_history_vector(),
        );
    }

    fun create_min_price_history_vector(): vector<MinPriceHistory> {
        let vec = vector::empty<MinPriceHistory>();
        let history = MinPriceHistory {
            price: decimal::from(0),
            last_update: 0,
        };
        let i = 0;
        while (i < 24) {
            vector::push_back(&mut vec, history);
            i = i + 1;
        };
        vec
    }

    #[test_only]
    struct USDC has copy, drop, store {}

    #[test_only]
    use sui::test_scenario;

    #[test_only]
    use sui::test_utils;

    #[test]
    fun apm_test() {
        let admin = @0xAA;
        let coin_type = type_name::get<USDC>();

        let scenario_value = test_scenario::begin(admin);
        let scenario = &mut scenario_value;

        let (market, ac_table_cap_interest_models, ac_table_cap_risk_models) = market::new(test_scenario::ctx(scenario));
        let (x_oracle, x_oracle_policy_cap) = protocol::oracle_t::init_t(scenario);
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::increment_for_testing(&mut clock, 3600 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(1, 0)); // $1

        set_apm_threshold(&mut market, coin_type, 100);
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(!is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        clock::increment_for_testing(&mut clock, 1800 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(1000, 0)); // $1000
        // this will trigger the APM, because of the last recorded price within the same hour
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        clock::increment_for_testing(&mut clock, 1800 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(1000, 0)); // $1000
        // this will trigger the APM, even the last recorded price is equal in the previous hour
        // because the min price in 24h is still $1
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        clock::increment_for_testing(&mut clock, 3600 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(1, 0)); // $1
        // this will NOT trigger the APM, because the price goes down
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(!is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        clock::increment_for_testing(&mut clock, 3600 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(15, 1)); // $1.5
        // this will NOT trigger the APM, because the price just up 50% from the lowest in 24 hours
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(!is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        clock::increment_for_testing(&mut clock, 3600 * 1000);
        x_oracle::x_oracle::update_price<USDC>(&mut x_oracle, &clock, protocol::oracle_t::calc_scaled_price(2, 0)); // $2
        // this will trigger the APM, because the price up 100% from the lowest in 24 hours
        let is_fluctuate = is_price_fluctuate(
            &market,
            &x_oracle,
            coin_type,
            &clock,
        );
        assert(is_fluctuate, 0);
        record_min_price_history(&mut market, &x_oracle, coin_type, &clock);

        test_utils::destroy(clock);
        test_utils::destroy(x_oracle);
        test_utils::destroy(x_oracle_policy_cap);
        test_utils::destroy(market);
        test_utils::destroy(ac_table_cap_interest_models);
        test_utils::destroy(ac_table_cap_risk_models);
        test_scenario::end(scenario_value);
    }
}