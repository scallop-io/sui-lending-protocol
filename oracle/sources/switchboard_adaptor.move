module oracle::switchboard_adaptor {
  use std::type_name::TypeName;
  use std::fixed_point32;
  use sui::math;
  use switchboard::aggregator::{Self, Aggregator};
  use switchboard::math as switchboard_math;
  use oracle::switchboard_registry::{assert_aggregator, SwitchboardRegistry};
  use std::fixed_point32::FixedPoint32;
  use sui::object::{UID, ID};
  use sui::table::Table;
  use switchboard::math::SwitchboardDecimal;
  use sui::object;
  use sui::table;
  use std::type_name;
  use sui::tx_context::TxContext;
  use sui::transfer;

  /// The number of decimal places in the price.
  const PRICE_PRECISION: u8 = 8;
  const U64_MAX: u128 = 0xFFFFFFFFFFFFFFFF;

  const SWITCHBOARD_PRICE_ERROR : u64 = 0;


  struct SwitchboardData has store {
    price: FixedPoint32,
    timestamp: u64,
    aggregator_id: ID,
  }

  /**
   * Data structure for storing the latest price and timestamp for switchboard aggregators.
   * Why we need this:
    * 1. We need multiple aggregators when calculating the value of a obligation.
    * 2. But in Move we can't pass in a vector of aggregators to a function.
   * So the solution is:
   * We have a SwitchboardBundle that stores the latest price and timestamp for each aggregator.
   * Here, we need to use programmable transaction to update the SwitchboardBundle before other operations.
   * The steps are:
    * 1. call **bundle_switchboard_aggregators** mutliple times with programmable transaction to update the SwitchboardBundle.
    * 2. The rest of the operations can use the SwitchboardBundle to get the latest price and timestamp.
    * 3. Verify the timestamp and aggregator of the price data in SwitchboardBundle to ensure that the price is fresh with the help of switchboard_registry.
   */
  struct SwitchboardBundle has key {
    id: UID,
    table: Table<TypeName, SwitchboardData>
  }

  fun init(ctx: &mut TxContext) {
    let switchboard_bundle = SwitchboardBundle {
      id: object::new(ctx),
      table: table::new(ctx)
    };
    transfer::share_object(switchboard_bundle);
  }

  // bundle the prices from different aggregators into a SwitchboardBundle.
  // This function should be called with programmable transaction.
  // The switchboard_registry is used to verify the aggregator.
  public fun bundle_switchboard_aggregators<T>(
    switchboard_bundle: &mut SwitchboardBundle,
    switchboard_registry: &SwitchboardRegistry,
    switchboard_aggregator: &Aggregator,
  ) {
    let coin_type = type_name::get<T>();
    assert_aggregator(switchboard_registry, coin_type, switchboard_aggregator);

    let (price, timestamp) = aggregator::latest_value(switchboard_aggregator);
    let aggregator_id = object::id(switchboard_aggregator);
    let switchboard_data = table::borrow_mut(&mut switchboard_bundle.table, coin_type);
    switchboard_data.price = convert_to_fixed_point32(price);
    switchboard_data.timestamp = timestamp;
    switchboard_data.aggregator_id = aggregator_id;
  }

  fun convert_to_fixed_point32(price: SwitchboardDecimal): FixedPoint32 {
    let (result, scale_factor, negative) = switchboard_math::unpack(price);
    // TODO: check the negative flag, how to handle negative price?
    assert!(negative == false, SWITCHBOARD_PRICE_ERROR);

    let price_scale = result * (math::pow(10, PRICE_PRECISION) as u128) / (math::pow(10, scale_factor) as u128);
    assert!(price_scale <= U64_MAX, SWITCHBOARD_PRICE_ERROR);

    fixed_point32::create_from_rational(
      (price_scale as u64),
      math::pow(10, PRICE_PRECISION),
    )
  }


  public fun get_switchboard_price(
    switchboard_bundle: &SwitchboardBundle,
    coin_type: TypeName,
  ): FixedPoint32 {
    let switchboard_data = table::borrow(&switchboard_bundle.table, coin_type);
    switchboard_data.price
  }
}
