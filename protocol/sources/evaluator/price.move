/// TODO: intergrate real oracle
/// use multiple oracles to aggregate the prices to prevent price manipulation
module protocol::price {
  
  use std::type_name::{TypeName, get};
  use sui::math;
  use math::fr::{Self, fr, Fr};
  
  use sui::sui::SUI;
  use test_coin::btc::BTC;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  public fun get_price(typeName: TypeName): Fr {
    if (typeName == get<BTC>()) {
      fr(1678766, 100)
    } else if (typeName == get<ETH>()) {
      fr(121000, 100)
    } else if (typeName == get<USDC>()) {
      fr(100, 100)
    } else if (typeName == get<SUI>()) {
      fr(866, 100)
    } else {
      fr(0, 100)
    }
  }
  
  public fun value_usd(coinType: TypeName, coinAmount: u64, decimals: u8): Fr {
    let price = get_price(coinType);
    let decimalAmount = fr::fr(coinAmount, math::pow(10, decimals));
    fr::mul(price, decimalAmount)
  }
}
