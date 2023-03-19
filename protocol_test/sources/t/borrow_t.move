#[test_only]
module protocol_test::borrow_t {
  use protocol::borrow;
  use protocol::obligation::Obligation;
  use protocol::reserve::Reserve;
  use protocol::coin_decimals_registry::CoinDecimalsRegistry;
  use sui::test_scenario::Scenario;
  use protocol::obligation::ObligationKey;
  use sui::test_scenario;
  use sui::balance::Balance;
  
  public fun borrow_t<T>(
    scenario: &mut Scenario,
    postion: &mut Obligation,
    obligationKey: &ObligationKey,
    reserve: &mut Reserve,
    coinDecimalsRegistry: &CoinDecimalsRegistry,
    now: u64,
    borrowAmount: u64,
  ): Balance<T> {
    let ctx = test_scenario::ctx(scenario);
    borrow::borrow_t<T>(postion, obligationKey, reserve, coinDecimalsRegistry, now, borrowAmount, ctx)
  }
}
