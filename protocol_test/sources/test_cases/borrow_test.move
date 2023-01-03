module protocol_test::borrow_test {
  
  #[test_only]
  use protocol_test::app_test::{app_init, add_interest_model, add_risk_model};
  #[test_only]
  use sui::test_scenario;
  #[test_only]
  use protocol_test::open_position_t::open_position_t;
  #[test_only]
  use protocol_test::mint_t::mint_t;
  #[test_only]
  use test_coin::usdc::USDC;
  #[test_only]
  use sui::coin;
  #[test_only]
  use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
  #[test_only]
  use test_coin::eth::ETH;
  #[test_only]
  use protocol_test::deposit_collateral_t::deposit_collateral_t;
  #[test_only]
  use sui::math;
  #[test_only]
  use protocol_test::borrow_t::borrow_t;
  #[test_only]
  use protocol::coin_decimals_registry;
  #[test_only]
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  #[test_only]
  use sui::balance;
  // #[test_only]
  // use protocol_test::withdraw_collateral_t::withdraw_collateral_t;
  #[test_only]
  use protocol_test::liquidate_t::liquidate_t;
  #[test_only]
  use std::debug;
  
  #[test]
  public fun borrow_test() {
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let senarioValue = test_scenario::begin(admin);
    let senario = &mut senarioValue;
    let (bank, adminCap) = app_init(senario, admin);
    let usdcInterestParams = usdc_interest_model_params();
    let initTime = 100;
    add_interest_model<USDC>(&mut bank, &adminCap, &usdcInterestParams, initTime);
    let ethRiskParams = eth_risk_model_params();
    add_risk_model<ETH>(&mut bank, &adminCap, &ethRiskParams);
    let coinDecimalsRegistiry = coin_decimals_registry_init(senario);
    coin_decimals_registry::register_decimals<USDC>(&mut coinDecimalsRegistiry, 9);
    coin_decimals_registry::register_decimals<ETH>(&mut coinDecimalsRegistiry, 18);
    
    test_scenario::next_tx(senario, lender);
    let usdcAmount = math::pow(10, 13);
    let mintTime = 200;
    let usdcCoin = coin::mint_for_testing<USDC>(usdcAmount, test_scenario::ctx(senario));
    let bankCoin = mint_t(senario, lender, &mut bank, mintTime, usdcCoin);
    assert!(coin::value(&bankCoin) == usdcAmount, 0);
    test_scenario::return_to_address(lender, bankCoin);
    
    test_scenario::next_tx(senario, borrower);
    let ethAmount = math::pow(10, 18);
    let ethCoin = coin::mint_for_testing<ETH>(ethAmount, test_scenario::ctx(senario));
    let (position, positionKey) = open_position_t(senario, borrower);
    deposit_collateral_t(senario, &mut position, ethCoin);
  
    test_scenario::next_tx(senario, borrower);
    let borrowTime = 300;
    let borrowAmount = 700 * math::pow(10, 9);
    let borrowed = borrow_t<USDC>(senario, &mut position, &positionKey, &mut bank, &coinDecimalsRegistiry, borrowTime, borrowAmount);
    assert!(balance::value(&borrowed) == borrowAmount, 0);
    balance::destroy_for_testing(borrowed);
    
    let liquidator = @0xDD;
    test_scenario::next_tx(senario, liquidator);
    let liqTime = 300 + 365 * 24 * 3600 * 80;
    let liqRepayAmount = 95 * math::pow(10, 8);
    let liqRepayCoin = coin::mint_for_testing<USDC>(liqRepayAmount, test_scenario::ctx(senario));
    let (restRepayBalance, collateralBalance) = liquidate_t<USDC, ETH>(
      &mut position, &mut bank, &coinDecimalsRegistiry, liqRepayCoin, liqTime
    );
    assert!(balance::value(&restRepayBalance) == 0, 0);
    debug::print(&collateralBalance);
    assert!(balance::value(&collateralBalance) == math::pow(10, 16), 1);
    
    balance::destroy_for_testing(restRepayBalance);
    balance::destroy_for_testing(collateralBalance);
    
    
    
    
    test_scenario::return_shared(coinDecimalsRegistiry);
    test_scenario::return_shared(bank);
    test_scenario::return_shared(position);
    test_scenario::return_to_address(admin, adminCap);
    test_scenario::return_to_address(borrower, positionKey);
    test_scenario::end(senarioValue);
  }
}
