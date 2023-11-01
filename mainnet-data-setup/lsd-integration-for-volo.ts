import { SuiTxBlock } from '@scallop-io/sui-kit';
import { riskModels } from './risk-models';
import { oracles } from './asset-oracles';
import { coinTypes, coinMetadataIds } from './chain-data';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  IncentiveRewardFactor,
} from '../contracts/protocol';
import { pythRuleTxBuilder } from '../contracts/sui_x_oracle';
import {
  decimalsRegistryTxBuilder,
} from '../contracts/libs/coin_decimals_registry';
import { interestModels } from './interest-models';
import { incentiveRewardFactors } from './incentive-reward-factors';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { buildMultiSigTx } from './multi-sig';

const integrateLSD = (txBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.vSui, riskModel: riskModels.vSui },
  ];
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.vSui, interestModel: interestModels.vSui },
  ];
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: coinTypes.vSui, metadataId: coinMetadataIds.vSui },
  ];
  const oraclePairs: { type: string, pythPriceObject: string  }[] = [
    { type: coinTypes.vSui, pythPriceObject: oracles.vSui.pythPriceObjectId },
  ];
  const outflowLimiterPairs: { type: string, outflowLimiter: OutflowLimiterModel }[] = [
    { type: coinTypes.vSui, outflowLimiter: outflowRateLimiters.vSui },
  ];
  const incentiveRewardFactorPairs: { type: string, incentiveRewardFactor: IncentiveRewardFactor }[] = [
    { type: coinTypes.vSui, incentiveRewardFactor: incentiveRewardFactors.vSui },
  ];

  // register decimals
  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(txBlock, pair.metadataId, pair.type);
  });
  // add risk models
  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(txBlock, pair.riskModel, pair.type);
  });
  // add interest models
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(txBlock, pair.interestModel, pair.type);
  });
  // register pyth price objects
  oraclePairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(txBlock, pair.pythPriceObject, pair.type);
  });
  // add outflow limiters
  outflowLimiterPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(txBlock, pair.outflowLimiter, pair.type);
  });
  // add incentive reward factors
  incentiveRewardFactorPairs.forEach(pair => {
    protocolTxBuilder.setIncentiveRewardFactor(txBlock, pair.incentiveRewardFactor, pair.type);
  });

  return buildMultiSigTx(txBlock);
}

integrateLSD(new SuiTxBlock()).then(console.log);