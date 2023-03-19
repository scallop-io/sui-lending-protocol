#[test_only]
module protocol_test::borrow_test {
  
  use sui::test_scenario;
  use sui::coin;
  use sui::math;
  use sui::balance;
  use protocol_test::app_test::app_init;
  use protocol_test::open_obligation_t::open_obligation_t;
  use protocol_test::mint_t::mint_t;
  use protocol_test::constants::{usdc_interest_model_params, eth_risk_model_params};
  use protocol_test::deposit_collateral_t::deposit_collateral_t;
  use protocol_test::borrow_t::borrow_t;
  use protocol::coin_decimals_registry;
  use protocol_test::coin_decimals_registry_t::coin_decimals_registry_init;
  use protocol_test::interest_model_t::add_interest_model_t;
  use protocol_test::risk_model_t::add_risk_model_t;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  #[test]
  public fun borrow_test() {
    let usdcDecimals = 9;
    let ethDecimals = 9;
    
    let admin = @0xAD;
    let lender = @0xAA;
    let borrower = @0xBB;
    let senarioValue = test_scenario::begin(admin);
    let senario = &mut senarioValue;
    let (reserve, adminCap) = app_init(senario, admin);
    let usdcInterestParams = usdc_interest_model_params();
    let initTime = 100;
    add_interest_model_t<USDC>(senario, &mut reserve, &adminCap, &usdcInterestParams, initTime);
    let ethRiskParams = eth_risk_model_params();
    add_risk_model_t<ETH>(senario, &mut reserve, &adminCap, &ethRiskParams);
    let coinDecimalsRegistiry = coin_decimals_registry_init(senario);
    coin_decimals_registry::register_decimals_t<USDC>(&mut coinDecimalsRegistiry, usdcDecimals);
    coin_decimals_registry::register_decimals_t<ETH>(&mut coinDecimalsRegistiry, ethDecimals);
    
    test_scenario::next_tx(senario, lender);
    let usdcAmount = math::pow(10, usdcDecimals + 4);
    let mintTime = 200;
    let usdcCoin = coin::mint_for_testing<USDC>(usdcAmount, test_scenario::ctx(senario));
    let reserveCoinBalance = mint_t(senario, lender, &mut reserve, mintTime, usdcCoin);
    assert!(balance::value(&reserveCoinBalance) == usdcAmount, 0);
    balance::destroy_for_testing(reserveCoinBalance);
    
    test_scenario::next_tx(senario, borrower);
    let ethAmount = math::pow(10, ethDecimals);
    let ethCoin = coin::mint_for_testing<ETH>(ethAmount, test_scenario::ctx(senario));
    let (obligation, obligationKey) = open_obligation_t(senario, borrower);
    deposit_collateral_t(senario, &mut obligation, &mut reserve, ethCoin);
  
    test_scenario::next_tx(senario, borrower);
    let borrowTime = 300;
    let borrowAmount = 699 * math::pow(10, usdcDecimals);
    let borrowed = borrow_t<USDC>(senario, &mut obligation, &obligationKey, &mut reserve, &coinDecimalsRegistiry, borrowTime, borrowAmount);
    assert!(balance::value(&borrowed) == borrowAmount, 0);
    balance::destroy_for_testing(borrowed);
    
    test_scenario::return_shared(coinDecimalsRegistiry);
    test_scenario::return_shared(reserve);
    test_scenario::return_shared(obligation);
    test_scenario::return_to_address(admin, adminCap);
    test_scenario::return_to_address(borrower, obligationKey);
    test_scenario::end(senarioValue);
  }
}
