module oracle::multi_oracle_strategy {

  use std::type_name::TypeName;
  use std::fixed_point32::FixedPoint32;
  use oracle::switchboard_adaptor::{Self, SwitchboardBundle};

  /// TODO: need to add supra, pyth oracles
  public fun get_price(
    switchboard_bundle: &SwitchboardBundle,
    typeName: TypeName,
  ): FixedPoint32 {
    switchboard_adaptor::get_switchboard_price(
      switchboard_bundle,
      typeName,
    )
  }
}
