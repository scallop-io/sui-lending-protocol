#[test_only]
module protocol_test::market_t {
    use protocol::market::Market;
    use std::fixed_point32::{Self, FixedPoint32};
    use x::ac_table;
    use std::type_name;
    use protocol::market as market_lib;
    use protocol::interest_model as interest_model_lib;
    use math::u64;
    use math::fixed_point32_empower;
  
    public fun calc_interest_rate<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
    ): FixedPoint32 {    
        let util_rate = fixed_point32::create_from_rational(curr_borrow, curr_borrow + curr_cash);
        let coin_type = type_name::get<T>();
        let interest_models = market_lib::interest_models(market);
        let interest_model = ac_table::borrow(interest_models, coin_type);
        let interest_rate = interest_model_lib::calc_interest(interest_model, util_rate);
        interest_rate
    }

    public fun calc_growth_interest<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_borrow_index: u64,
        time_delta: u64,
    ): FixedPoint32 {
        let index_delta = fixed_point32::multiply_u64(curr_borrow_index, fixed_point32_empower::mul(
            fixed_point32_empower::from_u64(time_delta), 
            calc_interest_rate<T>(market, curr_borrow, curr_cash)
        ));
        let new_borrow_index = curr_borrow_index + index_delta;
        fixed_point32_empower::sub(fixed_point32::create_from_rational(new_borrow_index, curr_borrow_index), fixed_point32_empower::from_u64(1))
    }

    public fun calc_mint_amount(
        market_coin_supply: u64,
        amount: u64,
        curr_debt: u64,
        curr_cash: u64,
    ): u64 {    
        u64::mul_div(amount, market_coin_supply, curr_cash + curr_debt)
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
