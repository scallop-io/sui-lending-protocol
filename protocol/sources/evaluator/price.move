/// TODO: intergrate real oracle
module protocol::price {
  
  use std::type_name::{TypeName, get};
  use sui::sui::SUI;
  use math::fr::{fr, Fr};
  
  use test_coin::btc::BTC;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  
  public fun get_price(typeName: TypeName): Fr {
    if (typeName == get<BTC>()) {
      fr(1678766, 100)
    } else if (typeName == get<ETH>()) {
      fr(121000, 100)
    } else if (typeName == get<USDC>()) {
      fr(101, 100)
    } else if (typeName == get<SUI>()) {
      fr(866, 100)
    } else {
      fr(0, 100)
    }
  }
}
