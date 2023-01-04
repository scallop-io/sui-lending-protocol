module protocol::app {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::transfer;
  use x::ac_table::AcTableCap;
  use protocol::bank::{Self, Bank};
  use protocol::interest_model::{Self, InterestModels, InterestModelChange};
  use protocol::risk_model::{Self, RiskModels};
  
  struct AdminCap has key, store {
    id: UID,
    interestModelCap: AcTableCap<InterestModels>,
    riskModelCap: AcTableCap<RiskModels>
  }
  
  fun init(ctx: &mut TxContext) {
    init_internal(ctx)
  }
  
  #[test_only]
  public fun init_t(ctx: &mut TxContext) {
    init_internal(ctx)
  }
  
  fun init_internal(ctx: &mut TxContext) {
    let (bank, interestModelCap, riskModelCap) = bank::new(ctx);
    let adminCap = AdminCap {
      id: object::new(ctx),
      interestModelCap,
      riskModelCap
    };
    transfer::share_object(bank);
    transfer::transfer(adminCap, tx_context::sender(ctx));
  }
  
  public entry fun create_interest_model_change<T>(
    adminCap: &AdminCap,
    baseRatePerSec: u64,
    lowSlope: u64,
    kink: u64,
    highSlope: u64,
    reserveFactor: u64,
    scale: u64,
    minBorrowAmount: u64,
    ctx: &mut TxContext,
  ) {
    let interestModelChange = interest_model::create_interest_model_change<T>(
      &adminCap.interestModelCap,
      baseRatePerSec,
      lowSlope,
      kink,
      highSlope,
      reserveFactor,
      scale,
      minBorrowAmount,
      ctx,
    );
    transfer::share_object(interestModelChange);
  }
  
  public entry fun add_interest_model<T>(
    bank: &mut Bank,
    adminCap: &AdminCap,
    interestModelChange: &mut InterestModelChange<T>,
    now: u64,
    ctx: &mut TxContext,
  ) {
    let interestModels = bank::interest_models_mut(bank);
    interest_model::add_interest_model<T>(
      interestModels,
      &adminCap.interestModelCap,
      interestModelChange,
      ctx
    );
    bank::register_coin<T>(bank, now);
  }
  
  public entry fun add_risk_model<T>(
    bank: &mut Bank,
    adminCap: &AdminCap,
    collateralFactor: u64, // exp. 70%,
    liquidationFactor: u64, // exp. 80%,
    liquidationPanelty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
  ) {
    let riskModels = bank::risk_models_mut(bank);
    risk_model::register_risk_model<T>(
      riskModels,
      &adminCap.riskModelCap,
      collateralFactor,
      liquidationFactor,
      liquidationPanelty,
      liquidationDiscount,
      scale,
    )
  }
}
