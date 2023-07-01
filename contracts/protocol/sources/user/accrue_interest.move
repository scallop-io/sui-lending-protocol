module protocol::accrue_interest {

  use sui::clock::{Self, Clock};
  use protocol::market::{Self, Market};
  use protocol::obligation::{Self, Obligation};

  /// Accrue interest for all markets.
  public fun accrue_interest_for_market(
    market: &mut Market,
    clock: &Clock,
  ) {
    let now = clock::timestamp_ms(clock) / 1000;
    market::accrue_all_interests(market, now);
  }

  /// Accrue interest for all markets and the given obligation.
  /// This function is used when liquidator wants to liquidate an obligation.
  /// Because liquidator need to know the exact amount of obligation to be liquidated
  ///
  /// It can also be used when borrower wants to accrue the reward point for the obligation.
  public fun accrue_interest_for_market_and_obligation(
    market: &mut Market,
    obligation: &mut Obligation,
    clock: &Clock,
  ) {
    accrue_interest_for_market(market, clock);
    obligation::accrue_interests_and_rewards(obligation, market);
  }
}
