module protocol::accrue_interest {

  use sui::clock::{Self, Clock};
  use protocol::market::{Self, Market};
  use protocol::obligation::{Self, Obligation};
  use protocol::version::{Self, Version};

  /// Accrue interest for all markets.
  public fun accrue_interest_for_market(
    version: &Version,
    market: &mut Market,
    clock: &Clock,
  ) {
    version::assert_current_version(version);

    let now = clock::timestamp_ms(clock) / 1000;
    market::accrue_all_interests(market, now);
  }

  /// Accrue interest for all markets and the given obligation.
  /// This function is used when liquidator wants to liquidate an obligation.
  /// Because liquidator need to know the exact amount of obligation to be liquidated
  ///
  /// It can also be used when borrower wants to accrue the reward point for the obligation.
  public fun accrue_interest_for_market_and_obligation(
    version: &Version,
    market: &mut Market,
    obligation: &mut Obligation,
    clock: &Clock,
  ) {
    version::assert_current_version(version);

    accrue_interest_for_market(version, market, clock);
    obligation::accrue_interests_and_rewards(obligation, market);
  }
}
