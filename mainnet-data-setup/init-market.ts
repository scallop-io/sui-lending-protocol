import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  BorrowFee
} from '../contracts/protocol';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { coinMetadataIds, coinTypes } from './chain-data';
import { SupplyLimits } from './supply-limits';
import { BorrowLimits } from './borrow-limits';
import { borrowFees } from './borrow-fee';
import { FlashloanFees } from './flashloan-fees';
import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';
import { suiKit } from 'sui-elements';
import { pythRuleStructType, xOracleTxBuilder } from 'contracts/sui_x_oracle';
import { ApmThresholds } from './apm-threshold';
import { MinCollaterals } from './min-collateral';

export const initMarket = async (suiTxBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.haSui, riskModel: riskModels.haSui },
    { type: coinTypes.sui, riskModel: riskModels.sui },
    { type: coinTypes.nativeUsdc, riskModel: riskModels.nativeUsdc },
  ];

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.haSui, interestModel: interestModels.haSui },
    { type: coinTypes.sui, interestModel: interestModels.sui },
    { type: coinTypes.nativeUsdc, interestModel: interestModels.nativeUsdc },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    { type: coinTypes.haSui, outflowLimit: outflowRateLimiters.haSui },
    { type: coinTypes.sui, outflowLimit: outflowRateLimiters.sui },
    { type: coinTypes.nativeUsdc, outflowLimit: outflowRateLimiters.nativeUsdc },
  ];

  const supplyLimitList: { type: string, limit: number }[] = [
    {type: coinTypes.haSui, limit: SupplyLimits.haSui},
    {type: coinTypes.sui, limit: SupplyLimits.sui},
    {type: coinTypes.nativeUsdc, limit: SupplyLimits.nativeUsdc},
  ];

  const borrowLimitList: { type: string, limit: number }[] = [
    { type: coinTypes.haSui, limit: BorrowLimits.haSui },
    { type: coinTypes.sui, limit: BorrowLimits.sui },
    { type: coinTypes.nativeUsdc, limit: BorrowLimits.nativeUsdc },
  ];

  const isolatedAssetStatus: { type: string, status: boolean }[] = [
  ];

  const borrowFeePairs: { type: string, borrowFee: BorrowFee }[] = [
    {type: coinTypes.haSui, borrowFee: borrowFees.haSui},
    {type: coinTypes.sui, borrowFee: borrowFees.sui},
    {type: coinTypes.nativeUsdc, borrowFee: borrowFees.nativeUsdc},
  ];

  const flashloanFeeList: { type: string, fee: number }[] = [
    {type: coinTypes.haSui, fee: FlashloanFees.haSui},
    {type: coinTypes.sui, fee: FlashloanFees.sui},
    {type: coinTypes.nativeUsdc, fee: FlashloanFees.nativeUsdc},
  ];

  const decimalsList = [
    { type: coinTypes.haSui, metadata: coinMetadataIds.haSui },
    { type: coinTypes.sui, metadata: coinMetadataIds.sui },
    { type: coinTypes.nativeUsdc, metadata: coinMetadataIds.nativeUsdc },
  ];

  const xOraclePrimaryRules = [
    { type: coinTypes.haSui, rule: pythRuleStructType },
    { type: coinTypes.sui, rule: pythRuleStructType },
    { type: coinTypes.nativeUsdc, rule: pythRuleStructType },
  ];

  const apmThresholds = [
    { type: coinTypes.haSui, threshold: ApmThresholds.haSui },
    { type: coinTypes.sui, threshold: ApmThresholds.sui },
    { type: coinTypes.nativeUsdc, threshold: ApmThresholds.nativeUsdc },
  ]

  const minCollaterals = [
    { type: coinTypes.haSui, minCollateral: MinCollaterals.haSui },
    { type: coinTypes.sui, minCollateral: MinCollaterals.sui },
    { type: coinTypes.nativeUsdc, minCollateral: MinCollaterals.nativeUsdc },
  ]

  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(suiTxBlock, pair.riskModel, pair.type);
  });
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(suiTxBlock, pair.interestModel, pair.type);
  });
  outflowLimitPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(suiTxBlock, pair.outflowLimit, pair.type);
  });
  supplyLimitList.forEach(pair => {
    protocolTxBuilder.setSupplyLimit(suiTxBlock, pair.limit, pair.type);
  });
  borrowLimitList.forEach(pair => {
    protocolTxBuilder.setBorrowLimit(suiTxBlock, pair.limit, pair.type);
  });
  isolatedAssetStatus.forEach(pair => {
    protocolTxBuilder.updateIsolatedAssetStatus(suiTxBlock, pair.status, pair.type);
  });
  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(suiTxBlock, pair.borrowFee, pair.type);
  });
  flashloanFeeList.forEach(pair => {
    protocolTxBuilder.setFlashloanFee(suiTxBlock, pair.fee, pair.type);
  });
  xOraclePrimaryRules.forEach(pair => {
    xOracleTxBuilder.addPrimaryPriceUpdateRuleV2(suiTxBlock, pair.type, pair.rule);
  });
  decimalsList.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(suiTxBlock, pair.metadata, pair.type);
  });
  minCollaterals.forEach(pair => {
    protocolTxBuilder.updateMinCollateral(suiTxBlock, pair.minCollateral, pair.type);
  })
  apmThresholds.forEach(pair => {
    protocolTxBuilder.setApmThreshold(suiTxBlock, pair.threshold, pair.type);
  })
  // init table
  protocolTxBuilder.initMarketCoinPriceTable(suiTxBlock);
  // allow all whitelist
  protocolTxBuilder.whitelistAllowAll(suiTxBlock);

  const resp = await suiKit.signAndSendTxn(suiTxBlock);
  console.log(resp)
}

initMarket(new SuiTxBlock()).then(console.log).catch(console.error).finally(() => process.exit(0));