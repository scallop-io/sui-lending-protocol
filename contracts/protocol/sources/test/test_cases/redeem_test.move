#[test_only]
module protocol::redeem_test {
  
  use sui::test_scenario;
  use sui::coin::{Self, Coin};
  use sui::clock;
  use std::fixed_point32;
  use std::type_name;
  use x_oracle::x_oracle;
  use coin_decimals_registry::coin_decimals_registry;
  use protocol::borrow;
  use protocol::deposit_collateral;
  use protocol::mint;
  use protocol::redeem;
  use protocol::market;
  use protocol::interest_model;
  use protocol::version;
  use protocol::app_t::app_init;
  use protocol::market_t::calc_growth_interest;
  use protocol::market_t::calc_mint_amount;
  use protocol::market_t::calc_redeem_amount;
  use protocol::open_obligation_t::open_obligation_t;
  use protocol::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol::interest_model_t::add_interest_model_t;
  use protocol::oracle_t;
  use protocol::risk_model_t::add_risk_model_t;
  use decimal::decimal;
  use test_coin::usdc::USDC;
  use test_coin::eth::ETH;

  #[test]
  #[allow(deprecated_usage)]
  fun redeem_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;
    let lender_b = @0xBB;
    let borrower = @0xCC;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);

    test_scenario::next_tx(scenario, admin);

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);

    let eth_risk_params = eth_risk_model_params();
    add_risk_model_t<ETH>(scenario, &mut market, &admin_cap, &eth_risk_params);

    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let lender_a_market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    let lender_a_market_coin_amount = coin::value(&lender_a_market_coin);
    assert!(lender_a_market_coin_amount == usdc_amount, 0);

    test_scenario::next_tx(scenario, borrower);
    let eth_amount = std::u64::pow(10, eth_decimals + 5);
    let eth_coin = coin::mint_for_testing<ETH>(eth_amount, test_scenario::ctx(scenario));
    let (obligation, obligation_key) = open_obligation_t(scenario, &version);
    deposit_collateral::deposit_collateral(&version, &mut obligation, &mut market, eth_coin, test_scenario::ctx(scenario));

    let borrow_time = 300;
    clock::set_for_testing(&mut clock, borrow_time * 1000);
    x_oracle::update_price<USDC>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1, 0)); // $1
    x_oracle::update_price<ETH>(&mut x_oracle, &clock, oracle_t::calc_scaled_price(1000, 0)); // $1000

    test_scenario::next_tx(scenario, borrower);
    let borrow_amount = 5 * std::u64::pow(10, usdc_decimals + 3);
    let borrowed = borrow::borrow<USDC>(&version, &mut obligation, &obligation_key, &mut market, &coin_decimals_registry, borrow_amount, &x_oracle, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&borrowed) == borrow_amount, 0);
    coin::burn_for_testing(borrowed);

    test_scenario::next_tx(scenario, lender_b);
    let current_borrow_index = market::borrow_index(&market, type_name::get<USDC>());
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let mint_time = 400;
    clock::set_for_testing(&mut clock, mint_time * 1000);
    let expected_mint = calc_coin_to_scoin(&version, &mut market, type_name::get<USDC>(), &clock, usdc_amount);
    let lender_b_market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&lender_b_market_coin) == expected_mint, 0);

    let current_revenue = 0;
    let growth_interest_rate = calc_growth_interest<USDC>(
      &market,
      borrow_amount,
      usdc_amount - borrow_amount,
      current_revenue,
      current_borrow_index,
      mint_time - borrow_time,
    );
    let increased_debt = fixed_point32::multiply_u64(borrow_amount, growth_interest_rate);
    let current_revenue = fixed_point32::multiply_u64(increased_debt, interest_model::revenue_factor(market::interest_model(&market, type_name::get<USDC>())));

    let expected_mint_amount = calc_mint_amount(
      usdc_amount,
      usdc_amount,
      borrow_amount + increased_debt - current_revenue,
      usdc_amount - borrow_amount,
    );
    let lender_b_market_coin_amount = coin::value(&lender_b_market_coin);

    assert!(lender_b_market_coin_amount == expected_mint_amount, 0);
    coin::burn_for_testing(lender_b_market_coin);

    test_scenario::next_tx(scenario, lender_a);
    let redeem_time = 500;
    clock::set_for_testing(&mut clock, 500 * 1000);
    let current_borrow_index = market::borrow_index(&market, type_name::get<USDC>());


    let expected_redeem = calc_scoin_to_coin(&version, &mut market, type_name::get<USDC>(), &clock, lender_a_market_coin_amount);
    let redeemed_coin = redeem::redeem(&version, &mut market, lender_a_market_coin, &clock, test_scenario::ctx(scenario));
    assert!(expected_redeem == coin::value(&redeemed_coin), 0);

    let current_debt = borrow_amount + increased_debt;
    let current_cash = usdc_amount + usdc_amount - borrow_amount;
    let growth_interest_rate = calc_growth_interest<USDC>(
      &market,
      current_debt,
      current_cash,
      current_revenue,
      current_borrow_index,
      redeem_time - mint_time,
    );
    let increased_debt = fixed_point32::multiply_u64(current_debt, growth_interest_rate);
    let current_revenue = current_revenue + fixed_point32::multiply_u64(increased_debt, interest_model::revenue_factor(market::interest_model(&market, type_name::get<USDC>())));

    let expected_redeem_amount = calc_redeem_amount(
      lender_a_market_coin_amount + lender_b_market_coin_amount,
      lender_a_market_coin_amount,
      current_debt + increased_debt - current_revenue,
      current_cash,
    );

    assert!(coin::value(&redeemed_coin) == expected_redeem_amount, 0);
    coin::burn_for_testing(redeemed_coin);

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
  fun redeem_entry_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);

    test_scenario::next_tx(scenario, admin);

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);

    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let lender_a_market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&lender_a_market_coin) == usdc_amount, 0);

    test_scenario::next_tx(scenario, lender_a);
    redeem::redeem_entry(&version, &mut market, lender_a_market_coin, &clock, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, lender_a);
    let redeemed_coin = test_scenario::take_from_address<Coin<USDC>>(scenario, lender_a);
    assert!(coin::value(&redeemed_coin) == usdc_amount, 0);
    coin::burn_for_testing(redeemed_coin);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);
    
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::end(scenario_value);
  }
  
  #[test, expected_failure(abort_code=0x0000101, location=protocol::market)]
  fun non_whitelisted_redeem_failed_test() {
    let usdc_decimals = 9;
    let eth_decimals = 9;
    
    let admin = @0xAD;
    let lender_a = @0xAA;

    let scenario_value = test_scenario::begin(admin);
    let scenario = &mut scenario_value;

    let clock = clock::create_for_testing(test_scenario::ctx(scenario));
    let version = version::create_for_testing(test_scenario::ctx(scenario));
    let (market, admin_cap) = app_init(scenario);

    test_scenario::next_tx(scenario, admin);

    let (x_oracle, x_oracle_policy_cap) = oracle_t::init_t(scenario);

    let usdc_interest_params = usdc_interest_model_params();
    test_scenario::next_tx(scenario, admin);
    
    clock::set_for_testing(&mut clock, 100 * 1000);
    add_interest_model_t<USDC>(scenario, std::u64::pow(10, 18), 60 * 60 * 24, 30 * 60, &mut market, &admin_cap, &usdc_interest_params, &clock);

    let coin_decimals_registry = coin_decimals_registry_init(scenario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coin_decimals_registry, usdc_decimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coin_decimals_registry, eth_decimals);
    
    test_scenario::next_tx(scenario, lender_a);
    let usdc_amount = std::u64::pow(10, usdc_decimals + 4);
    clock::set_for_testing(&mut clock, 200 * 1000);
    let usdc_coin = coin::mint_for_testing<USDC>(usdc_amount, test_scenario::ctx(scenario));
    let lender_a_market_coin = mint::mint(&version, &mut market, usdc_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&lender_a_market_coin) == usdc_amount, 0);

    // only admin is in whitelist
    protocol::app::whitelist_switch_to_whitelist_mode(&admin_cap, &mut market);
    protocol::app::whitelist_add_address_to_whitelist(&admin_cap, &mut market, admin);

    test_scenario::next_tx(scenario, lender_a);
    let redeemed_coin = redeem::redeem(&version, &mut market, lender_a_market_coin, &clock, test_scenario::ctx(scenario));
    assert!(coin::value(&redeemed_coin) > usdc_amount, 0);
    coin::burn_for_testing(redeemed_coin);

    clock::destroy_for_testing(clock);
    version::destroy_for_testing(version);
    
    test_scenario::return_shared(x_oracle);
    test_scenario::return_shared(coin_decimals_registry);
    test_scenario::return_shared(market);
    test_scenario::return_to_address(admin, admin_cap);
    test_scenario::return_to_address(admin, x_oracle_policy_cap);
    test_scenario::end(scenario_value);
  }
  
  #[test_only]
  fun calc_coin_to_scoin(
    version: &protocol::version::Version,
    market: &mut protocol::market::Market, 
    coin_type: std::type_name::TypeName, 
    clock: &sui::clock::Clock,
    coin_amount: u64
  ): u64 {
    let (cash, debt, revenue, market_coin_supply) = get_reserve_stats(version, market, coin_type, clock);

    let scoin_amount = if (market_coin_supply > 0) {
      math::u64::mul_div(
        coin_amount,
        market_coin_supply,
        cash + debt - revenue
      )
    } else {
      coin_amount
    };

    // if the coin is too less, just throw error
    assert!(scoin_amount > 0, 1);
    
    scoin_amount
  }

  #[test_only]
  fun calc_scoin_to_coin(
    version: &protocol::version::Version,
    market: &mut protocol::market::Market, 
    coin_type: std::type_name::TypeName, 
    clock: &sui::clock::Clock,
    scoin_amount: u64
  ): u64 {
    let (cash, debt, revenue, market_coin_supply) = get_reserve_stats(version, market, coin_type, clock);
    
    let coin_amount = math::u64::mul_div(
      scoin_amount,
      cash + debt - revenue,
      market_coin_supply
    );

    coin_amount
  }


  #[test_only]
  fun get_reserve_stats(
    version: &protocol::version::Version,
    market: &mut protocol::market::Market,
    coin_type: std::type_name::TypeName,
    clock: &sui::clock::Clock,
  ): (u64, u64, u64, u64) {
    // update to the latest reserve stats
    // NOTE: this function needs to be called to get an accurate data
    protocol::accrue_interest::accrue_interest_for_market(
      version,
      market,
      clock
    );

    let vault = protocol::market::vault(market);
    let balance_sheets = protocol::reserve::balance_sheets(vault);

    let balance_sheet = x::wit_table::borrow(balance_sheets, coin_type);
    let (cash, debt, revenue, market_coin_supply) = protocol::reserve::balance_sheet(balance_sheet);
    (cash, debt, revenue, market_coin_supply)
  }
}