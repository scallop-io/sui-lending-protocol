module mobius_protocol::protocol_dynamics {
  
  use std::type_name::{Self, TypeName};
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self ,UID};
  use sui::transfer;
  use x::wit_table::WitTable;
  use x::ac_table::{Self, AcTable, AcTableOwnership};
  use x::ownership::Ownership;
  use math::exponential::{Self,Exp};
  use mobius_protocol::bank_state::{Self, BankStates, BankState};
  use mobius_protocol::collateral_config::{Self, CollateralConfigs, CollateralConfig};
  use mobius_protocol::interest_model::{Self, InterestModel, InterestModels};
  use mobius_protocol::coin_decimals_registry::{Self, CoinDecimalsRegistry};
  
  struct ProtocolDynamics has key {
    id: UID,
    collateralConfigs: AcTable<CollateralConfigs, TypeName, CollateralConfig>,
    interestModels: AcTable<InterestModels, TypeName, InterestModel>,
    bankStates: WitTable<BankStates, TypeName, BankState>,
    coinDecimalsRegistry: CoinDecimalsRegistry,
  }
  
  struct ProtocolDynamicsCap has key, store {
    id: UID,
    collateralConfigsOwnership: Ownership<AcTableOwnership>,
    interestModelsOwnership: Ownership<AcTableOwnership>,
  }
  
  fun init(ctx: &mut TxContext) {
    let (collateralConfigs, collateralConfigsOwnership) = collateral_config::new(ctx);
    let (interestModels, interestModelsOwnership) = interest_model::new(ctx);
    let bankStates = bank_state::new(ctx);
    let coinDecimalsRegistry = coin_decimals_registry::new(ctx);
    let protocolDynamics = ProtocolDynamics {
      id: object::new(ctx),
      collateralConfigs,
      interestModels,
      bankStates,
      coinDecimalsRegistry,
    };
    let protocolDynamicsCap = ProtocolDynamicsCap {
      id: object::new(ctx),
      collateralConfigsOwnership,
      interestModelsOwnership
    };
    transfer::share_object(protocolDynamics);
    transfer::transfer(protocolDynamicsCap, tx_context::sender(ctx));
  }
  
  // Set the collateral factor, admin only
  // Pass in the collateral factor enumerator and denominator
  public entry fun set_collateral_factor<CoinType>(
    protocolDynamics: &mut ProtocolDynamics,
    protocolDynamicsCap: &ProtocolDynamicsCap,
    collateralFactorEnu: u64,
    collateralFactorDeno: u64,
  ) {
    let coinType = type_name::get<CoinType>();
    collateral_config::register_collateral_type(
      &mut protocolDynamics.collateralConfigs,
      &protocolDynamicsCap.collateralConfigsOwnership,
      coinType,
      collateralFactorEnu,
      collateralFactorDeno
    );
  }
  
  // Set the interest model
  public entry fun set_interest_model<CoinType>(
    protocolDynamics: &mut ProtocolDynamics,
    protocolDynamicsCap: &ProtocolDynamicsCap,
    baseRatePersecEnu: u128,
    baseRatePersecDeno: u128,
    lowSlopeEnu: u128,
    lowSlopeDeno: u128,
    kinkEnu: u128,
    kinkDeno: u128,
    highSlopeEnu: u128,
    highSlopeDeno: u128,
    reserveFactorEnu: u128,
    reserveFactorDeno: u128,
  ) {
    let coinType = type_name::get<CoinType>();
    interest_model::add_interest_model(
      &mut protocolDynamics.interestModels,
      &protocolDynamicsCap.interestModelsOwnership,
      coinType,
      baseRatePersecEnu,
      baseRatePersecDeno,
      lowSlopeEnu,
      lowSlopeDeno,
      kinkEnu,
      kinkDeno,
      highSlopeEnu,
      highSlopeDeno,
      reserveFactorEnu,
      reserveFactorDeno,
    )
  }
  
  public fun get_borrow_mark(
    protocolDynamics: &ProtocolDynamics,
    typeName: TypeName,
  ): Exp {
    bank_state::borrow_mark(&protocolDynamics.bankStates, typeName)
  }
  
  public fun inccrue_interest(
    self: &mut ProtocolDynamics,
    typeName: TypeName,
    now: u64,
  ) {
    bank_state::accrue_interest(
      &mut self.bankStates,
      &self.interestModels,
      typeName,
      now
    )
  }
  
  // Always update interest rate after bank asset changes
  public fun update_interest_rate(
    protocolDynamics: &mut ProtocolDynamics,
    typeName: TypeName,
  ) {
    bank_state::update_interest_rate(
      &mut protocolDynamics.bankStates,
      &protocolDynamics.interestModels,
      typeName
    );
  }
  
  public fun update_state_after_repay(
    self: &mut ProtocolDynamics,
    typeName: TypeName,
    repayAmount: u64
  ) {
    bank_state::handle_repay(&mut self.bankStates, typeName, repayAmount);
  }
  
  public fun collateral_factor(
    protocolDynamics: &ProtocolDynamics,
    typeName: TypeName,
  ): Exp {
    let config = ac_table::borrow(&protocolDynamics.collateralConfigs, typeName);
    let (enu, deno) = collateral_config::collateral_factor(config);
    exponential::exp((enu as u128), (deno as u128))
  }
}
