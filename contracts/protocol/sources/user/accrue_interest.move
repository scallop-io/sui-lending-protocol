/// @title A module dedicated for accure the interest for base assets
/// @author Scallop Labs
/// @notice You can use this module to auto-compounding interests
module protocol::accrue_interest {

  use sui::clock::{Self, Clock};
  use protocol::market::{Self, Market};
  use protocol::obligation::{Self, Obligation};
  use protocol::version::{Self, Version};

  /// @notice Accrue interest for all base asset pools.
  /// @dev This is used to enforce the update of interests, can be triggered by anyone to compound the interests
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param clock The SUI system Clock object, 0x6
  public fun accrue_interest_for_market(
    version: &Version,
    market: &mut Market,
    clock: &Clock,
  ) {
    version::assert_current_version(version);

    let now = clock::timestamp_ms(clock) / 1000;
    market::accrue_all_interests(market, now);
  }

  /// @notice Accrue interests for the markets & the given obligation
  /// @dev This is used to update the debt in the obligation, for the later calculation of possible liquidation
  /// @param version The version control object, contract version must match with this
  /// @param market The Scallop market object, it contains base assets, and related protocol configs
  /// @param obligation The obligation that is intended for liquidation
  /// @param clock The SUI system Clock object, 0x6
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
