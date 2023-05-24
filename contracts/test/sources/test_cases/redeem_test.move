#[test_only]
module protocol_test::redeem_test {
  
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::balance;
  use sui::clock::Self as clock_lib;
  use std::fixed_point32;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol_test::app_t::app_init;
  use protocol_test::mint_t::mint_t;
  use protocol_test::deposit_collateral_t::deposit_collateral_t;
  use protocol_test::market_t::calc_growth_interest;
  use protocol_test::market_t::calc_mint_amount;
  use protocol_test::market_t::calc_redeem_amount;
  use protocol_test::borrow_t::borrow_t;
  use protocol_test::open_obligation_t::open_obligation_t;
  use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use protocol_test::oracle_t;
  use protocol_test::risk_model_t::add_risk_model_t;
  use protocol_test::redeem_t::redeem_t;
  use test_coin::usdc::USDC;
  use test_coin::eth::ETH;

  #[test]
  public fun redeem_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;
    let lender_b = @0xBB;
    let borrower = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let (market, admin_cap) = app_init(scenario, admin);

    test_scenario::next_tx(scenario, admin);

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario, admin);

    let usdc_interest_params = usdc_interest_model_params();
    let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    
    clock_lib::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);

    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);

    let coin_decimals_registry_obj = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry_obj, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry_obj, eth_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock_lib::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let lender_a_market_coin_balance = mint_t(scenario, lender_a, &mut market, usdc_coin, &clock);
    let lender_a_market_coin_amount = balance::value(&lender_a_market_coin_balance);
    assert!(lender_a_market_coin_amount == usdc_amount, 0);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = math::pow(10, eth_decimals + 5);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
    deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);

    let borrow_time = 300;
    clock_lib::set_for_testing(&mut clock, borrow_time * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 5 * math::pow(10, usdc_decimals + 3);
    let borrowed = borrow_t<USDC>(scenario, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry_obj, borrow_amount, &x_oracle, &clock);
    assert!(balance::value(&borrowed) == borrow_amount, 0);
    balance::destroy_for_testing(borrowed);

    test_scenario::next_tx(scenario, lender_b);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let mint_time = 400;
    clock_lib::set_for_testing(&mut clock, 400 * 1000);
    let lender_b_market_coin_balance = mint_t(scenario, lender_b, &mut market, usdc_coin, &clock);

    let growth_interest_rate = calc_growth_interest<USDC>(
      &market,
      borrow_amount,
      usdc_amount - borrow_amount,
      math::pow(10, 9),
      mint_time - borrow_time,
    );
    let increased_debt = fixed_point32::multiply_u64(borrow_amount, growth_interest_rate);

    let expected_mint_amount = calc_mint_amount(
      usdc_amount,
      usdc_amount,
      borrow_amount + increased_debt,
      usdc_amount - borrow_amount,
    );
    let lender_b_market_coin_amount = balance::value(&lender_b_market_coin_balance);

    assert!(lender_b_market_coin_amount == expected_mint_amount, 0);
    balance::destroy_for_testing(lender_b_market_coin_balance);

    test_scenario::next_tx(scenario, lender_a);
    let redeem_time = 500;
    clock_lib::set_for_testing(&mut clock, 500 * 1000);
    let market_coin = coin::from_balance(lender_a_market_coin_balance, test_scenario::ctx(scenario));
    let redeemed_coin = redeem_t(scenario, lender_a, &mut market, market_coin, &clock);

    let current_debt = borrow_amount + increased_debt;
    let current_cash = usdc_amount + usdc_amount - borrow_amount;
    let growth_interest_rate = calc_growth_interest<USDC>(
      &market,
      current_debt,
      current_cash,
      math::pow(10, 9),
      redeem_time - mint_time,
    );
    let increased_debt = fixed_point32::multiply_u64(current_debt, growth_interest_rate);

    let expected_redeem_amount = calc_redeem_amount(
      lender_a_market_coin_amount + lender_b_market_coin_amount,
      lender_a_market_coin_amount,
      current_debt + increased_debt,
      current_cash,
    );

    assert!(coin::value(&redeemed_coin) == expected_redeem_amount, 0);
    coin::burn_for_testing(redeemed_coin);

    clock_lib::destroy_for_testing(clock);
    
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry_obj);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }
}