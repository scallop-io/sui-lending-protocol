module protocol::apm {
    use std::vector;
    use std::type_name::TypeName;
    use sui::dynamic_field as df;
    use x_oracle::x_oracle::XOracle;
    use decimal::decimal::{Self, Decimal};
    use protocol::price::get_price;
    use protocol::market::{Self, Market};
    use sui::clock::{Self, Clock};
    use protocol::market_dynamic_keys::{min_price_history_key, apm_threshold_key, MinPriceHistoryKey, ApmThresholdKey};

    friend protocol::borrow;
    friend protocol::obligation;

    struct MinPriceHistory has copy, drop, store {
        price: Decimal,
        last_update: u64,
    }

    public(friend) fun set_apm_threshold(market: &mut Market, type_name: TypeName, apm_threshold_percentage: u8) {
        init_if_not_exists(market, type_name);

        if (df::exists_(market::uid(market), apm_threshold_key(type_name))) {
            let apm_threshold = df::borrow_mut<ApmThresholdKey, Decimal>(
                market::uid_mut(market),
                apm_threshold_key(type_name),
            );
            *apm_threshold = decimal::from_percent(apm_threshold_percentage);
        } else {
            df::add<ApmThresholdKey, Decimal>(
                market::uid_mut(market),
                apm_threshold_key(type_name),
                decimal::from_percent(apm_threshold_percentage),
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
            
            if (now - min_price_history.last_update <= 24 * 3600 && i != curr_index) {
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

        let price_increased_percentage = decimal::div(
            decimal::sub(current_price, min_price_in_24h),
            min_price_in_24h
        );

        let apm_threshold = df::borrow<ApmThresholdKey, Decimal>(market::uid(market), apm_threshold_key(type_name));
        if (decimal::gt(price_increased_percentage, *apm_threshold)) {
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
}