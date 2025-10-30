#[test_only]
module protocol::app_t {
  use sui::test_scenario::{Self, Scenario};
  use protocol::market::Market;
  use protocol::app::{Self, AdminCap};
  use whitelist::whitelist;
  use test_coin::usdc::USDC;
  use test_coin::usdt::USDT;  
  use test_coin::eth::ETH;
  
  public fun app_init(scenario: &mut Scenario): (Market, AdminCap) {
    app::init_t(test_scenario::ctx(scenario));
    let sender = test_scenario::sender(scenario);
    test_scenario::next_tx(scenario, sender);
    let adminCap = test_scenario::take_from_sender<AdminCap>(scenario);
    let market = test_scenario::take_shared<Market>(scenario);

    app::update_borrow_fee<USDC>(
      &adminCap,
      &mut market,
      0,
      1
    );

    app::update_supply_limit<USDC>(
      &adminCap,
      &mut market,
      1_000_000 * std::u64::pow(10, 9),
    );

    app::update_borrow_fee<USDT>(
      &adminCap,
      &mut market,
      0,
      1
    );

    app::update_borrow_limit<USDT>(
      &adminCap,
      &mut market,
      1_000_000 * std::u64::pow(10, 9),
    );

    app::update_borrow_limit<USDC>(
      &adminCap,
      &mut market,
      1_000_000 * std::u64::pow(10, 9),
    );

    app::update_borrow_limit<ETH>(
      &adminCap,
      &mut market,
      1_000 * std::u64::pow(10, 9),
    );    

    app::update_supply_limit<USDT>(
      &adminCap,
      &mut market,
      1_000_000 * std::u64::pow(10, 9),
    );        

    app::update_supply_limit<ETH>(
      &adminCap,
      &mut market,
      1_000 * std::u64::pow(10, 9),
    );

    app::update_min_collateral_amount<USDC>(
      &adminCap,
      &mut market,
       std::u64::pow(10, 9), // 1 USDC
    );

    app::update_min_collateral_amount<USDT>(
      &adminCap,
      &mut market,
       std::u64::pow(10, 9), // 1 USDT
    );

    app::update_min_collateral_amount<ETH>(
      &adminCap,
      &mut market,
       std::u64::pow(10, 9 - 3), // 0.001 ETH
    );

    app::init_market_coin_price_table(
      &adminCap,
      &mut market,
      test_scenario::ctx(scenario)
    );

    app::set_apm_threshold<ETH>(
      &adminCap,
      &mut market,
      200,
      test_scenario::ctx(scenario)
    );

    app::set_apm_threshold<USDC>(
      &adminCap,
      &mut market,
      200,
      test_scenario::ctx(scenario)
    );

    app::set_apm_threshold<USDT>(
      &adminCap,
      &mut market,
      200,
      test_scenario::ctx(scenario)
    );    

    app::whitelist_allow_all(&adminCap, &mut market);

    (market, adminCap)
  }
}
