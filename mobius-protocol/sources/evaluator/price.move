/// TODO: intergrate real oracle
module mobius_protocol::price {
  
  use std::type_name::{TypeName, get};
  use math::exponential::{Self, Exp};
  
  use test_coin::btc::BTC;
  use test_coin::eth::ETH;
  use test_coin::usdc::USDC;
  use sui::sui::SUI;
  
  public fun get_price(typeName: TypeName): Exp {
    if (typeName == get<BTC>()) {
      exponential::exp(1678766, 100)
    } else if (typeName == get<ETH>()) {
      exponential::exp(121000, 100)
    } else if (typeName == get<USDC>()) {
      exponential::exp(101, 100)
    } else if (typeName == get<SUI>()) {
      exponential::exp(866, 100)
    } else {
      exponential::exp(0, 100)
    }
  }
}
