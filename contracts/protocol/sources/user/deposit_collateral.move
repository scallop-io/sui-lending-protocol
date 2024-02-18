module protocol::deposit_collateral {
  
  use std::type_name::{Self, TypeName};
  use sui::object::{Self, ID};
  use sui::coin::{Self, Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use protocol::obligation::{Self, Obligation};
  use protocol::market::{Self, Market};
  use protocol::version::{Self, Version};
  use whitelist::whitelist;
  use protocol::error;
  
  struct CollateralDepositEvent has copy, drop {
    provider: address,
    obligation: ID,
    deposit_asset: TypeName,
    deposit_amount: u64,
  }
  
  public entry fun deposit_collateral<T>(
    version: &Version,
    obligation: &mut Obligation,
    market: &mut Market,
    coin: Coin<T>,
    ctx: &mut TxContext,
  ) {
    // check version
    version::assert_current_version(version);
    // check if sender is in whitelist
    assert!(
      whitelist::is_address_allowed(market::uid(market), tx_context::sender(ctx)),
      error::whitelist_error()
    );
    // check if obligation is locked
    assert!(
      obligation::deposit_collateral_locked(obligation) == false,
      error::obligation_locked()
    );

    let coin_type = type_name::get<T>();
    // check if collateral state is active
    assert!(
      market::is_collateral_active(market, coin_type),
      error::collateral_not_active_error()
    );

    let has_risk_model = market::has_risk_model(market, coin_type);
    assert!(has_risk_model == true, error::invalid_collateral_type_error());

    assert!(!obligation::has_coin_x_as_debt(obligation, coin_type), error::unable_to_deposit_a_borrowed_coin());
    
    emit(CollateralDepositEvent{
      provider: tx_context::sender(ctx),
      obligation: object::id(obligation),
      deposit_asset: coin_type,
      deposit_amount: coin::value(&coin),
    });
  
    market::handle_add_collateral<T>(market, coin::value(&coin));
    obligation::deposit_collateral(obligation, coin::into_balance(coin))
  }
}
