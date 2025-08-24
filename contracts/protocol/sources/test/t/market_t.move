#[test_only]
module protocol::market_t {
    use protocol::market::Market;
    use std::fixed_point32::{Self, FixedPoint32};
    use x::ac_table;
    use std::type_name;
    use protocol::market as market_lib;
    use protocol::interest_model as interest_model_lib;
    use math::u64;
    use decimal::decimal::{Self, Decimal};
  
    #[allow(deprecated_usage)]
    public fun calc_interest_rate<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_revenue: u64,
    ): (FixedPoint32, u64) {    
        let util_rate = fixed_point32::create_from_rational(curr_borrow, curr_borrow + curr_cash - curr_revenue);
        let coin_type = type_name::get<T>();
        let interest_models = market_lib::interest_models(market);
        let interest_model = ac_table::borrow(interest_models, coin_type);
        interest_model_lib::calc_interest(interest_model, util_rate)
    }

    public fun calc_growth_interest<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_revenue: u64,
        curr_borrow_index: Decimal,
        time_delta: u64,
    ): Decimal {
        let (interest_rate, interest_rate_scale) = calc_interest_rate<T>(market, curr_borrow, curr_cash, curr_revenue);
        let index_delta = decimal::mul(
            curr_borrow_index,
            decimal::mul(decimal::from(time_delta), 
                decimal::div(decimal::from_fixed_point32(interest_rate), decimal::from(interest_rate_scale))
            )
        );
        let new_borrow_index = decimal::add(curr_borrow_index, index_delta);
        let index_diff = decimal::div(new_borrow_index, curr_borrow_index);
        decimal::sub(index_diff, decimal::from(1))
    }

    public fun calc_growth_interest_on_obligation<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_revenue: u64,
        curr_borrow_index: Decimal,
        time_delta: u64,
    ): Decimal {
        let (interest_rate, interest_rate_scale) = calc_interest_rate<T>(market, curr_borrow, curr_cash, curr_revenue);
        let index_delta = decimal::mul(
            curr_borrow_index,
            decimal::mul(decimal::from(time_delta), 
                decimal::div(decimal::from_fixed_point32(interest_rate), decimal::from(interest_rate_scale))
            )
        );
        let new_borrow_index = decimal::add(curr_borrow_index, index_delta);

        let new_borrow_index_u64 = borrow_index_from_decimal_to_u64_round_up(new_borrow_index);
        let curr_borrow_index_u64 = borrow_index_from_decimal_to_u64_round_up(curr_borrow_index);
        let index_diff = decimal::div(decimal::from(new_borrow_index_u64), decimal::from(curr_borrow_index_u64));
        decimal::sub(index_diff, decimal::from(1))
    }

    public fun borrow_index_from_decimal_to_u64_round_up(
        borrow_index: Decimal,
    ): u64 {
        // accrue interest first, to get the latest borrow amount
        let result = if (decimal::to_scaled_val(borrow_index) % std::u256::pow(10, 9) == 0) {
        // if the new borrow index is divisible by 10^9, we can safely convert it to u64
        ((decimal::to_scaled_val(borrow_index) / std::u256::pow(10, 9)) as u64)
        } else {
        // if the new borrow index is not divisible by 10^9, we need to round it up
        ((decimal::to_scaled_val(borrow_index) / std::u256::pow(10, 9)) as u64) + 1
        };

        result
    }

    public fun calc_mint_amount(
        market_coin_supply: u64,
        amount: u64,
        curr_debt: u64,
        curr_cash: u64,
    ): u64 {    
        decimal::floor(
            decimal::div(
                decimal::mul(
                    decimal::from(amount),
                    decimal::from(market_coin_supply)
                ),
                decimal::from(curr_cash + curr_debt)
            )
        )
    }

    public fun calc_redeem_amount(
        market_coin_supply: u64,
        amount: u64,
        curr_debt: u64,
        curr_cash: u64,
    ): u64 {    
        u64::mul_div(amount, curr_cash + curr_debt, market_coin_supply)
    }
}
