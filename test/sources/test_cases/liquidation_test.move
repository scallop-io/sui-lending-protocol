#[test_only]
module protocol_test::liquidation_test {
  
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::balance;
  use sui::clock::Self as clock_lib;
  use protocol_test::app_t::app_init;
  use protocol_test::open_obligation_t::open_obligation_t;
  use protocol_test::mint_t::mint_t;
  use protocol_test::constants::{Self, usdc_interest_model_params, eth_risk_model_params};
  use protocol_test::deposit_collateral_t::deposit_collateral_t;
  use protocol_test::borrow_t::borrow_t;
  use protocol_test::liquidate_t;
  use protocol::coin_decimals_registry;
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use protocol_test::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use oracle::price_feed::{Self, PriceFeedHolder, PriceFeedCap};
  use math::fixed_point32_empower;
  use std::fixed_point32::{Self, FixedPoint32};
  
  #[test]
  public fun liquidation_test() {
    // Scenario:
    // 0. the price of USDC = $0.5 and the price of ETH = $1000
    // 1. `lender` deposit 10000 USDC
    // 2. `borrower` deposit collateral 1 ETH
    // 3. `borrower` borrow 850 USDC
    //    - 850 USDC = $425, still below the collateral factor
    // 4. USDC price becomes $1, at this moment borrower can be liquidated
    // 5. call liquidation
    // 6. asserting:
    //    - calculated how coin used to repay the debt
    //    - convert how many amount of returned collateral in debt type coin, also deduct the discount
    //    - check if they are equal
    
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let liquidator = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let (market, admin_cap) = app_init(scenario, admin);
    let usdc_interest_params = usdc_interest_model_params();

    price_feed::init_oracle(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let price_feeds = test_scenario::take_shared<PriceFeedHolder>(scenario);
    let price_feed_cap = test_scenario::take_from_address<PriceFeedCap>(scenario, admin);
    price_feed::add_price_feed<ETH>(&price_feed_cap, &mut price_feeds, 1000, 1); // 1000 USD
    price_feed::add_price_feed<USDC>(&price_feed_cap, &mut price_feeds, 1, 2); // 0.5 USD
    test_scenario::next_tx(scenario, admin);

    let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    
    clock_lib::increment_for_testing(&mut clock, 100);
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock_lib::increment_for_testing(&mut clock, 100);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin_balance = mint_t(scenario, lender, &mut market, usdc_coin, &clock);
    assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
    balance::destroy_for_testing(market_coin_balance);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = math::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
    deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);
  
    test_scenario::next_tx(scenario, borrower);
    clock_lib::increment_for_testing(&mut clock, 100);
    let borrow_amount = 850 * math::pow(10, usdc_decimals);
    let borrowed = borrow_t<USDC>(scenario, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &price_feeds, &clock);
    assert!(balance::value(&borrowed) == borrow_amount, 0);
    balance::destroy_for_testing(borrowed);

    test_scenario::next_tx(scenario, admin);    
    price_feed::update_price<USDC>(&price_feed_cap, &mut price_feeds, 1, 1); // 1 USD

    test_scenario::next_tx(scenario, liquidator);    
    let usdc_amount = 900 * math::pow(10, usdc_decimals);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));

    let (coin_debt, coin_collateral) = liquidate_t::liquidate_t<USDC, ETH>(
        &mut obligation, 
        &mut market,
        &coin_decimals_registry,
        usdc_coin,
        &price_feeds,
        &clock,
        test_scenario::ctx(scenario),
    );

    let repaid_debt_amount = usdc_amount - coin::value(&coin_debt); // original amount - remaining amount

    // liq exchange rate will help converting the coin including the discount
    let liq_exchange_rate = calc_liq_exchange_rate(
      fixed_point32::create_from_rational(5, 100),
      usdc_decimals,
      eth_decimals,
      fixed_point32::create_from_rational(1, 1),
      fixed_point32::create_from_rational(1000, 1),
    );
    let discounted_collateral_in_debt_coin_amount = fixed_point32::divide_u64(coin::value(&coin_collateral), liq_exchange_rate);

    assert!(repaid_debt_amount == discounted_collateral_in_debt_coin_amount, 1);

    coin::burn_for_testing(coin_debt);
    coin::burn_for_testing(coin_collateral);

    clock_lib::destroy_for_testing(clock);

    test_scenario::return_to_address(admin, price_feed_cap);
    test_scenario::return_shared(price_feeds);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[test]
  public fun liquidation_with_borrow_weight_test() {
    // Scenario:
    // 0. the price of USDC = $0.25 and the price of ETH = $1000
    //    - borrow weight USDC = 2
    // 1. `lender` deposit 10000 USDC
    // 2. `borrower` deposit collateral 1 ETH
    // 3. `borrower` borrow 850 USDC
    //    - 850 USDC = $425, still below the collateral factor
    // 4. USDC price becomes $0.5, at this moment borrower can be liquidated
    // 5. call liquidation
    // 6. asserting:
    //    - calculated how coin used to repay the debt
    //    - convert how many amount of returned collateral in debt type coin, also deduct the discount
    //    - check if they are equal
    
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let liquidator = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let (market, admin_cap) = app_init(scenario, admin);
    let usdc_interest_params = usdc_interest_model_params();
    let new_borrow_weight = constants::borrow_weight(&usdc_interest_params) * 2;
    constants::set_borrow_weight(&mut usdc_interest_params, new_borrow_weight);

    price_feed::init_oracle(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    let price_feeds = test_scenario::take_shared<PriceFeedHolder>(scenario);
    let price_feed_cap = test_scenario::take_from_address<PriceFeedCap>(scenario, admin);
    price_feed::add_price_feed<ETH>(&price_feed_cap, &mut price_feeds, 1000, 1); // 1000 USD
    price_feed::add_price_feed<USDC>(&price_feed_cap, &mut price_feeds, 1, 4); // 0.25 USD
    test_scenario::next_tx(scenario, admin);

    let clock = clock_lib::create_for_testing(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, admin);
    
    clock_lib::increment_for_testing(&mut clock, 100);
    add_interest_model_t<USDC>(scenario, math::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = math::pow(10, usdc_decimals + 4);
    clock_lib::increment_for_testing(&mut clock, 100);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin_balance = mint_t(scenario, lender, &mut market, usdc_coin, &clock);
    assert!(balance::value(&market_coin_balance) == usdc_amount, 0);
    balance::destroy_for_testing(market_coin_balance);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = math::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, borrower);
    deposit_collateral_t(scenario, &mut obligation, &mut market, eth_coin);
  
    test_scenario::next_tx(scenario, borrower);
    clock_lib::increment_for_testing(&mut clock, 100);
    let borrow_amount = 850 * math::pow(10, usdc_decimals);
    let borrowed = borrow_t<USDC>(scenario, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &price_feeds, &clock);
    assert!(balance::value(&borrowed) == borrow_amount, 0);
    balance::destroy_for_testing(borrowed);

    test_scenario::next_tx(scenario, admin);    
    price_feed::update_price<USDC>(&price_feed_cap, &mut price_feeds, 1, 2); // 0.5 USD

    test_scenario::next_tx(scenario, liquidator);    
    let usdc_amount = 900 * math::pow(10, usdc_decimals);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));

    let (coin_debt, coin_collateral) = liquidate_t::liquidate_t<USDC, ETH>(
        &mut obligation, 
        &mut market,
        &coin_decimals_registry,
        usdc_coin,
        &price_feeds,
        &clock,
        test_scenario::ctx(scenario),
    );

    let repaid_debt_amount = (usdc_amount - coin::value(&coin_debt)); // original amount - remaining amount

    // liq exchange rate will help converting the coin including the discount
    let liq_exchange_rate = calc_liq_exchange_rate(
      fixed_point32::create_from_rational(5, 100),
      usdc_decimals,
      eth_decimals,
      fixed_point32::create_from_rational(1, 2),
      fixed_point32::create_from_rational(1000, 1),
    );
    let discounted_collateral_debt_coin_amount = fixed_point32::divide_u64(coin::value(&coin_collateral), liq_exchange_rate);
    assert!(repaid_debt_amount == discounted_collateral_debt_coin_amount, 1);

    coin::burn_for_testing(coin_debt);
    coin::burn_for_testing(coin_collateral);

    clock_lib::destroy_for_testing(clock);

    test_scenario::return_to_address(admin, price_feed_cap);
    test_scenario::return_shared(price_feeds);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  fun calc_liq_exchange_rate(
    liq_discount: FixedPoint32,
    debt_decimal: u8,
    collateral_decimal: u8,
    debt_price: FixedPoint32,
    collateral_price: FixedPoint32,
  ): FixedPoint32 {
    let exchange_rate = fixed_point32_empower::mul(
      fixed_point32::create_from_rational(math::pow(10, collateral_decimal), math::pow(10, debt_decimal)),
      fixed_point32_empower::div(debt_price, collateral_price),
    );
    let liq_exchange_rate = fixed_point32_empower::div(
      exchange_rate,
      fixed_point32_empower::sub(fixed_point32_empower::from_u64(1), liq_discount)
    );
    liq_exchange_rate
  }
}