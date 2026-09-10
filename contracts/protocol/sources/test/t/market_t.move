#[test_only]
module protocol::market_t {
    use protocol::market::Market;
  use std::uq32_32::{Self, UQ32_32};
    use x::ac_table;
    use std::type_name;
    use protocol::market as market_lib;
    use protocol::interest_model as interest_model_lib;
    use math::u64;
    use decimal::decimal::{Self, Decimal};
    use math::UQ32_32_empower;

    #[allow(deprecated_usage)]
    public fun calc_interest_rate<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_revenue: u64,
    ): (UQ32_32, u64) {    
        let util_rate = uq32_32::from_quotient(curr_borrow, curr_borrow + curr_cash - curr_revenue);
        let coin_type = type_name:: with_defining_ids<T>();
        let interest_models = market_lib::interest_models(market);
        let interest_model = ac_table::borrow(interest_models, coin_type);
        interest_model_lib::calc_interest(interest_model, util_rate)
    }

    public fun calc_growth_interest<T>(
        market: &Market,
        curr_borrow: u64,
        curr_cash: u64,
        curr_revenue: u64,
        curr_borrow_index: u64,
        time_delta: u64,
    ): UQ32_32 {
        let (interest_rate, interest_rate_scale) = calc_interest_rate<T>(market, curr_borrow, curr_cash, curr_revenue);
        let index_delta = uq32_32::int_mul(curr_borrow_index, UQ32_32_empower::mul(
            UQ32_32_empower::from_u64(time_delta), 
            interest_rate
        ));
        let index_delta = index_delta / interest_rate_scale;
        let new_borrow_index = curr_borrow_index + index_delta;
        UQ32_32_empower::sub(uq32_32::from_quotient(new_borrow_index, curr_borrow_index), UQ32_32_empower::from_u64(1))
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
        std::u64::mul_div(amount, curr_cash + curr_debt, market_coin_supply)
    }
}
