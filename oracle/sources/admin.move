module oracle::admin {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  
  use oracle::oracle::{Self, OracleRegistry};
  use oracle::pair;
  
  struct AdminCap has key, store {
    id: UID,
  }
  
  fun init(ctx: &mut TxContext) {
    transfer::transfer(
      AdminCap { id: object::new(ctx) },
      tx_context::sender(ctx)
    )
  }
  
  // DEV
  public entry fun create_dev_price_oracles(_: &AdminCap, registry: &mut OracleRegistry, ctx: &mut TxContext) {
    oracle::create_oracle<pair::BTC_USD>(registry, ctx);
    oracle::create_oracle<pair::ETH_USD>(registry, ctx);
    oracle::create_oracle<pair::SUI_USD>(registry, ctx);
    oracle::create_oracle<pair::USDC_USD>(registry, ctx);
  }
}
