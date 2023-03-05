module protocol::app {
  use sui::tx_context::{Self, TxContext};
  use sui::object::{Self, UID};
  use sui::clock::{Self, Clock};
  use sui::transfer;
  use x::ac_table::AcTableCap;
  use x::one_time_lock_value::OneTimeLockValue;
  use protocol::bank::{Self, Bank};
  use protocol::interest_model::{Self, InterestModels, InterestModel};
  use protocol::risk_model::{Self, RiskModels, RiskModel};
  
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
    interestModelChange: &mut OneTimeLockValue<InterestModel>,
    clock: &Clock,
    ctx: &mut TxContext,
  ) {
    let interestModels = bank::interest_models_mut(bank);
    interest_model::add_interest_model<T>(
      interestModels,
      &adminCap.interestModelCap,
      interestModelChange,
      ctx
    );
    let now = clock::timestamp_ms(clock);
    bank::register_coin<T>(bank, now);
  }
  
  public entry fun create_risk_model_change<T>(
    adminCap: &AdminCap,
    collateralFactor: u64, // exp. 70%,
    liquidationFactor: u64, // exp. 80%,
    liquidationPanelty: u64, // exp. 7%,
    liquidationDiscount: u64, // exp. 95%,
    scale: u64,
    maxCollateralAmount: u64,
    ctx: &mut TxContext,
  ) {
    let riskModelChange = risk_model::create_risk_model_change<T>(
      &adminCap.riskModelCap,
      collateralFactor, // exp. 70%,
      liquidationFactor, // exp. 80%,
      liquidationPanelty, // exp. 7%,
      liquidationDiscount, // exp. 95%,
      scale,
      maxCollateralAmount,
      ctx
    );
    transfer::share_object(riskModelChange);
  }
  
  public entry fun add_risk_model<T>(
    bank: &mut Bank,
    adminCap: &AdminCap,
    riskModelChange: &mut OneTimeLockValue<RiskModel>,
    ctx: &mut TxContext
  ) {
    let riskModels = bank::risk_models_mut(bank);
    risk_model::add_risk_model<T>(
      riskModels,
      &adminCap.riskModelCap,
      riskModelChange,
      ctx
    );
    bank::register_collateral<T>(bank);
  }
}
