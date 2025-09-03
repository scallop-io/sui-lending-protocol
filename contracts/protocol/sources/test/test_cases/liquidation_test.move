#[test_only]
module protocol::liquidation_test {
  
  use sui::test_scenario;
  use sui::coin::{Self, Coin};
  use sui::clock;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::borrow;
  use protocol::collateral_value;
  use protocol::debt_value;
  use protocol::deposit_collateral;
  use protocol::liquidate;
  use protocol::mint;
  use protocol::version;
  use protocol::app_t::app_init;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::constants::{Self, usdc_interest_model_params, eth_risk_model_params};
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::risk_model_t::add_risk_model_t;
  use protocol::oracle_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use math::fixed_point32_empower;
  use std::fixed_point32::{Self, FixedPoint32};
  
  #[test]
  #[allow(deprecated_usage)]
  fun liquidation_test() {
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
    // 7. assert the debt should be healthy
    
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let liquidator = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);
    let usdc_interest_params = usdc_interest_model_params();

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(5, 1)); // $0.5
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 850 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1

    test_scenario::next_tx(scenario, liquidator);    
    let usdc_amount = 900 * std::u64::pow(10, usdc_decimals);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));

    liquidate::liquidate_entry<USDC, ETH>(
        &version,
        &mut obligation, 
        &mut market,
        usdc_coin,
        &coin_decimals_registry,
        &x_oracle,
        &clock,
        test_scenario::ctx(scenario),
    );
    test_scenario::next_tx(scenario, liquidator);    
    let coin_debt = test_scenario::take_from_address<Coin<USDC>>(scenario, liquidator);
    let coin_collateral = test_scenario::take_from_address<Coin<ETH>>(scenario, liquidator);

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

    let collaterals_value_with_liq_factor = collateral_value::collaterals_value_usd_for_liquidation(&obligation, &market, &coin_decimals_registry, &x_oracle, &clock);
    let weighted_debts_value = debt_value::debts_value_usd_with_weight(&obligation, &coin_decimals_registry, &market, &x_oracle, &clock);

    assert!(fixed_point32_empower::gt(weighted_debts_value, collaterals_value_with_liq_factor) == false, 2);

    coin::burn_for_testing(coin_debt);
    coin::burn_for_testing(coin_collateral);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[test]
  #[allow(deprecated_usage)]
  fun liquidation_with_borrow_weight_test() {
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
    // 7. assert the debt should be healthy
    
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let liquidator = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;
    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);
    let usdc_interest_params = usdc_interest_model_params();
    let new_borrow_weight = constants::borrow_weight(&usdc_interest_params) * 2;
    constants::set_borrow_weight(&mut usdc_interest_params, new_borrow_weight);

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);
    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);
    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);
    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&market_coin) == usdc_amount, 0);
    coin::burn_for_testing(market_coin);
    
    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));
  
    clock::set_for_testing(&mut clock, 300 * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(25, 2)); // $0.25
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 850 * std::u64::pow(10, usdc_decimals);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(5, 1)); // $0.5

    test_scenario::next_tx(scenario, liquidator);    
    let usdc_amount = 900 * std::u64::pow(10, usdc_decimals);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));

    let (coin_debt, coin_collateral) = liquidate::liquidate<USDC, ETH>(
        &version,
        &mut obligation, 
        &mut market,
        usdc_coin,
        &coin_decimals_registry,
        &x_oracle,
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

    let collaterals_value_with_liq_factor = collateral_value::collaterals_value_usd_for_liquidation(&obligation, &market, &coin_decimals_registry, &x_oracle, &clock);
    let weighted_debts_value = debt_value::debts_value_usd_with_weight(&obligation, &coin_decimals_registry, &market, &x_oracle, &clock);

    assert!(fixed_point32_empower::gt(weighted_debts_value, collaterals_value_with_liq_factor) == false, 2);

    coin::burn_for_testing(coin_debt);
    coin::burn_for_testing(coin_collateral);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);

    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::return_to_address(borrower, obligation_key);
    test_scenario::end(scenario_value);
  }

  #[allow(deprecated_usage)]
  fun calc_liq_exchange_rate(
    liq_discount: FixedPoint32,
    debt_decimal: u8,
    collateral_decimal: u8,
    debt_price: FixedPoint32,
    collateral_price: FixedPoint32,
  ): FixedPoint32 {
    let exchange_rate = fixed_point32_empower::mul(
      fixed_point32::create_from_rational(std::u64::pow(10, collateral_decimal), std::u64::pow(10, debt_decimal)),
      fixed_point32_empower::div(debt_price, collateral_price),
    );
    let liq_exchange_rate = fixed_point32_empower::div(
      exchange_rate,
      fixed_point32_empower::sub(fixed_point32_empower::from_u64(1), liq_discount)
    );
    liq_exchange_rate
  }
}