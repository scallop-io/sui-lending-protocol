module protocol::asset_active_state {
  use std::type_name::TypeName;
  use sui::tx_context::TxContext;
  use x::wit_table::{Self, WitTable};

  friend protocol::market;

  struct BaseAssetActiveStates has drop {}
  struct CollateralActiveStates has drop {}

  struct AssetActiveStates has store {
    base: WitTable<BaseAssetActiveStates, TypeName, bool>,
    collateral: WitTable<CollateralActiveStates, TypeName, bool>,
  }

  public(friend) fun new(ctx: &mut TxContext): AssetActiveStates {
    AssetActiveStates{
      base: wit_table::new(BaseAssetActiveStates {}, true, ctx),
      collateral: wit_table::new(CollateralActiveStates {}, true, ctx),
    }
  }

  public(friend) fun is_base_asset_active(
    states: &AssetActiveStates,
    type_name: TypeName,
  ): bool {
    if (wit_table::contains(&states.base, type_name)) {
      *wit_table::borrow(&states.base, type_name)
    } else {
      false
    }
  }

  public(friend) fun is_collateral_active(
    states: &AssetActiveStates,
    type_name: TypeName,
  ): bool {
    if (wit_table::contains(&states.collateral, type_name)) {
      *wit_table::borrow(&states.collateral, type_name)
    } else {
      false
    }
  }

  public(friend) fun set_base_asset_active_state(
    states: &mut AssetActiveStates,
    type_name: TypeName,
    is_active: bool,
  ) {
    if (wit_table::contains(&states.base, type_name)) {
      wit_table::remove(BaseAssetActiveStates{}, &mut states.base, type_name);
    };
    wit_table::add(BaseAssetActiveStates{}, &mut states.base, type_name, is_active);
  }

  public(friend) fun set_collateral_active_state(
    states: &mut AssetActiveStates,
    type_name: TypeName,
    is_active: bool,
  ) {
    if (wit_table::contains(&states.collateral, type_name)) {
      wit_table::remove(CollateralActiveStates {}, &mut states.collateral, type_name);
    };
    wit_table::add(CollateralActiveStates {}, &mut states.collateral, type_name, is_active);
  }
}
