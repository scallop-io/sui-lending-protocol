module protocol_whitelist::protocol_whitelist {

  use sui::package::Publisher;
  use sui::event::emit;

  use x::witness;
  use whitelist::whitelist;

  use protocol::market::{Self, Market};
  use sui::object;

  struct ScallopWhitelistAdded has copy, drop {
    address: address,
    market: address,
  }

  struct ScallopWhitelistRemoved has copy, drop {
    address: address,
    market: address,
  }

  struct ScallopWhitelistAllowAll has copy, drop {
    market: address,
  }

  struct ScallopWhitelistRejectAll has copy, drop {
    market: address,
  }

  public fun add_whitelist_address(
    publisher: &Publisher,
    market: &mut Market,
    address: address
  ) {
    let market_uid = market::uid(market);
    if (whitelist::in_whitelist(market_uid, address)) {
      return;
    };
    let market_witness = witness::from_publisher<Market>(publisher);
    let market_uid_mut = market::uid_mut_delegated(market, market_witness);
    whitelist::add_whitelist_address(market_uid_mut, address);
    emit(ScallopWhitelistAdded{
      address,
      market: object::id_to_address(&object::id(market)),
    });
  }

  public fun remove_whitelist_address(
    publisher: &Publisher,
    market: &mut Market,
    address: address
  ) {
    let market_uid = market::uid(market);
    if (whitelist::in_whitelist(market_uid, address) == false) {
      return;
    };
    let market_witness = witness::from_publisher<Market>(publisher);
    let market_uid_mut = market::uid_mut_delegated(market, market_witness);
    whitelist::remove_whitelist_address(market_uid_mut, address);
    emit(ScallopWhitelistRemoved{
      address,
      market: object::id_to_address(&object::id(market)),
    });
  }

  public fun switch_to_whitelist_mode(
    publisher: &Publisher,
    market: &mut Market,
  ) {
    let market_witness = witness::from_publisher<Market>(publisher);
    let market_uid_mut = market::uid_mut_delegated(market, market_witness);
    whitelist::switch_to_whitelist_mode(market_uid_mut);
  }

  public fun allow_all(
    publisher: &Publisher,
    market: &mut Market,
  ) {
    let market_uid = market::uid(market);
    if (whitelist::is_allow_all(market_uid)) {
      return;
    };
    let market_witness = witness::from_publisher<Market>(publisher);
    let market_uid_mut = market::uid_mut_delegated(market, market_witness);
    whitelist::allow_all(market_uid_mut);
    emit(ScallopWhitelistAllowAll{
      market: object::id_to_address(&object::id(market)),
    });
  }

  public fun reject_all(
    publisher: &Publisher,
    market: &mut Market,
  ) {
    let market_uid = market::uid(market);
    if (whitelist::is_reject_all(market_uid)) {
      return;
    };
    let market_witness = witness::from_publisher<Market>(publisher);
    let market_uid_mut = market::uid_mut_delegated(market, market_witness);
    whitelist::reject_all(market_uid_mut);
    emit(ScallopWhitelistRejectAll{
      market: object::id_to_address(&object::id(market)),
    });
  }
}
