import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js";
import { SuiTxBlock, SuiTxArg } from "@scallop-io/sui-kit";

export type RiskModel = {
  collateralFactor: number,
  liquidationFactor: number,
  liquidationPanelty: number,
  liquidationDiscount: number,
  scale: number,
  maxCollateralAmount: number,
}

export type InterestModel = {
  baseRatePerSec: number,
  lowSlope: number,
  kink: number,
  highSlope: number,
  marketFactor: number,
  scale: number,
  minBorrowAmount: number,
  borrow_weight: number,
}

export type OutflowLimiterModel = {
  outflowLimit: number,
  outflowCycleDuration: number,
  outflowSegmentDuration: number,
}
export class ProtocolTxBuilder {
  constructor(
    public packageId: string,
    public adminCapId: string,
    public marketId: string,
  ) { }

  addRiskModel(
    suiTxBlock: SuiTxBlock,
    riskModel: RiskModel,
    coinType: string,
  ) {
    const createRiskModelChangeTarget = `${this.packageId}::app::create_risk_model_change`;
    let riskModelChange= suiTxBlock.moveCall(
      createRiskModelChangeTarget,
      [
        this.adminCapId,
        riskModel.collateralFactor,
        riskModel.liquidationFactor,
        riskModel.liquidationPanelty,
        riskModel.liquidationDiscount,
        riskModel.scale,
        riskModel.maxCollateralAmount,
      ],
      [coinType],
    );
    const addRiskModelTarget = `${this.packageId}::app::add_risk_model`;
    suiTxBlock.moveCall(
      addRiskModelTarget,
      [this.marketId, this.adminCapId, riskModelChange],
      [coinType],
    );
  }

  addInterestModel(
    suiTxBlock: SuiTxBlock,
    interestModel: InterestModel,
    coinType: string,
  ) {
    const createInterestModelChangeTarget = `${this.packageId}::app::create_interest_model_change`;
    let interestModelChange= suiTxBlock.moveCall(
      createInterestModelChangeTarget,
      [
        this.adminCapId,
        interestModel.baseRatePerSec,
        interestModel.lowSlope,
        interestModel.kink,
        interestModel.highSlope,
        interestModel.marketFactor,
        interestModel.scale,
        interestModel.minBorrowAmount,
        interestModel.borrow_weight,
      ],
      [coinType],
    );
    const addInterestModelTarget = `${this.packageId}::app::add_interest_model`;
    suiTxBlock.moveCall(
      addInterestModelTarget,
      [this.marketId, this.adminCapId, interestModelChange, SUI_CLOCK_OBJECT_ID],
      [coinType],
    );
  }

  addLimiter(
    suiTxBlock: SuiTxBlock,
    outflowLimiterModel: OutflowLimiterModel,
    coinType: string,
  ) {
    const addLimiterTarget = `${this.packageId}::app::add_limiter`;
    suiTxBlock.moveCall(
      addLimiterTarget,
      [
        this.adminCapId,
        this.marketId,
        outflowLimiterModel.outflowLimit,
        outflowLimiterModel.outflowCycleDuration,
        outflowLimiterModel.outflowSegmentDuration,
      ],
      [coinType],
    );
  }

  addWhitelistAddress(
    suiTxBlock: SuiTxBlock,
    address: string,
  ) {
    const marketUidMutTarget = `${this.packageId}::app::add_whitelist_address`;
    return suiTxBlock.moveCall(
      marketUidMutTarget,
      [this.adminCapId, this.marketId, address],
    );
  }

  supplyBaseAsset(
    suiTxBlock: SuiTxBlock,
    coinId: SuiTxArg,
    coinType: string,
  ) {
    suiTxBlock.moveCall(
      `${this.packageId}::mint::mint_entry`,
      [this.marketId, coinId, SUI_CLOCK_OBJECT_ID],
      [coinType]
    );
  }

  openObligation(suiTxBlock: SuiTxBlock) {
    return suiTxBlock.moveCall(
      `${this.packageId}::open_obligation::open_obligation`,
      [],
    );
  }

  returnObligation(
    suiTxBlock: SuiTxBlock,
    obligation: SuiTxArg,
    obligationHotPotato: SuiTxArg,
  ) {
    suiTxBlock.moveCall(
      `${this.packageId}::open_obligation::return_obligation`,
      [obligation, obligationHotPotato],
    );
  }

  addCollateral(
    suiTxBlock: SuiTxBlock,
    obligation: SuiTxArg,
    coin: SuiTxArg,
    coinType: string,
  ) {
    suiTxBlock.moveCall(
      `${this.packageId}::deposit_collateral::deposit_collateral`,
      [obligation, this.marketId, coin],
      [coinType]
    );
  }

  removeCollateral(
    suiTxBlock: SuiTxBlock,
    obligation: SuiTxArg,
    obligationKey: SuiTxArg,
    decimalsRegistry: SuiTxArg,
    withdrawAmount: number,
    xOracle: SuiTxArg,
    coinType: string,
  ) {
    return suiTxBlock.moveCall(
      `${this.packageId}::withdraw_collateral::withdraw_collateral`,
      [
        obligation,
        obligationKey,
        this.marketId,
        decimalsRegistry,
        withdrawAmount,
        xOracle,
        SUI_CLOCK_OBJECT_ID
      ],
      [coinType]
    );
  }


  borrowBaseAsset(
    suiTxBlock: SuiTxBlock,
    obligation: SuiTxArg,
    obligationKey: SuiTxArg,
    decimalsRegistry: SuiTxArg,
    brrowAmount: number,
    xOracle: SuiTxArg,
    coinType: string,
  ) {
    return suiTxBlock.moveCall(
      `${this.packageId}::borrow::borrow`,
      [
        obligation,
        obligationKey,
        this.marketId,
        decimalsRegistry,
        brrowAmount,
        xOracle,
        SUI_CLOCK_OBJECT_ID
      ],
      [coinType]
    );
  }
}
