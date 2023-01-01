module protocol::app {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use x::ac_table::AcTableCap;
  use protocol::bank::{Self, Bank};
  use protocol::interest_model::{Self, InterestModels};
  use protocol::risk_model::{Self, RiskModels};
  
  struct AdminCap has key, store {
    id: UID,
    interestModelCap: AcTableCap<InterestModels>,
    riskModelCap: AcTableCap<RiskModels>
  }
  
  fun init(ctx: &mut TxContext) {
    let (bank, interestModelCap, riskModelCap) = bank::new(ctx);
    let adminCap = AdminCap {
      id: object::new(ctx),
      interestModelCap,
      riskModelCap
    };
    transfer::share_object(bank);
    transfer::transfer(adminCap, tx_context::sender(ctx));
  }
  
  public entry fun add_interest_model<T>(
    bank: &mut Bank,
    adminCap: &AdminCap,
    baseRatePersecEnu: u64,
    baseRatePersecDeno: u64,
    lowSlopeEnu: u64,
    lowSlopeDeno: u64,
    kinkEnu: u64,
    kinkDeno: u64,
    highSlopeEnu: u64,
    highSlopeDeno: u64,
    reserveFactorEnu: u64,
    reserveFactorDeno: u64,
  ) {
    let interestModels = bank::interest_models_mut(bank);
    interest_model::add_interest_model<T>(
      interestModels,
      &adminCap.interestModelCap,
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
  
  public entry fun add_risk_model<T>(
    bank: &mut Bank,
    adminCap: &AdminCap,
    collateralFactorEnu: u64, // exp. 70%,
    collateralFactorDeno: u64,
    liquidationFactorEnu: u64, // exp. 80%,
    liquidationFactorDeno: u64,
    liquidationPaneltyEnu: u64, // exp. 7%,
    liquidationPaneltyDeno: u64,
    liquidationDiscountEnu: u64, // exp. 95%,
    liquidationDiscountDeno: u64,
    minBorrowAmount: u64,
  ) {
    let riskModels = bank::risk_models_mut(bank);
    risk_model::register_risk_model<T>(
      riskModels,
      &adminCap.riskModelCap,
      collateralFactorEnu,
      collateralFactorDeno,
      liquidationFactorEnu,
      liquidationFactorDeno,
      liquidationPaneltyEnu,
      liquidationPaneltyDeno,
      liquidationDiscountEnu,
      liquidationDiscountDeno,
      minBorrowAmount,
    )
  }
}
