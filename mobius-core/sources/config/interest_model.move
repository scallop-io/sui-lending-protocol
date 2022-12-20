/// Interest model for coin
/// TODO: implement this placeholder
module mobius_core::interest_model {
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  
  struct InterestModel<phantom UnderlyingCoin, phantom BankCoin> has key {
    id: UID,
    baseBorrowRatePersec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64
  }
  
  /// only admin
  public (friend) fun new<UnderlyingCoin, BankCoin>(
    ctx: &mut TxContext
  ): InterestModel<UnderlyingCoin, BankCoin> {
    InterestModel<UnderlyingCoin, BankCoin> {
      id: object::new(ctx),
      baseBorrowRatePersec: 0,
      lowSlope: 0,
      kink: 0,
      highSlope: 0
    }
  }
  
  public fun calc_interest<UnderlyingCoin, BankCoin>(
    self: &InterestModel<UnderlyingCoin, BankCoin>,
    ultilizationRate: u64
  ): u64 {
  
  }
}
