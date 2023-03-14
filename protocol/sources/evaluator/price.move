/// TODO: intergrate real oracle
/// use multiple oracles to aggregate the prices to prevent price manipulation
module protocol::price {
  
  use std::type_name::{TypeName, get};
  use sui::math;
  use sui::sui::SUI;
  use test_coin::btc::BTC;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use std::fixed_point32::{Self, FixedPoint32};
  use math::fixed_point32_empower;
  
  public fun get_price(typeName: TypeName): FixedPoint32 {
    if (typeName == get<BTC>()) {
      fixed_point32::create_from_rational(1678766, 100)
    } else if (typeName == get<ETH>()) {
      fixed_point32::create_from_rational(100000, 100)
    } else if (typeName == get<USDC>()) {
      fixed_point32::create_from_rational(100, 100)
    } else if (typeName == get<SUI>()) {
      fixed_point32::create_from_rational(866, 100)
    } else {
      fixed_point32_empower::zero()
    }
  }
  
  public fun value_usd(coinType: TypeName, coinAmount: u64, decimals: u8): FixedPoint32 {
    let price = get_price(coinType);
    let decimalAmount = fixed_point32::create_from_rational(coinAmount, math::pow(10, decimals));
    fixed_point32_empower::mul(price, decimalAmount)
  }
}
