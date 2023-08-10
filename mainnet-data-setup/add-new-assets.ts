import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { incentiveRewardFactors } from './incentive-reward-factors';
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

const addNewAssets = (txBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.cetus, riskModel: riskModels.cetus },
    { type: coinTypes.wormholeBtc, riskModel: riskModels.wormholeBtc },
    { type: coinTypes.wormholeSol, riskModel: riskModels.wormholeSol },
    { type: coinTypes.wormholeApt, riskModel: riskModels.wormholeApt },
  ];
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.cetus, interestModel: interestModels.cetus },
    { type: coinTypes.wormholeBtc, interestModel: interestModels.wormholeBtc },
    { type: coinTypes.wormholeSol, interestModel: interestModels.wormholeSol },
    { type: coinTypes.wormholeApt, interestModel: interestModels.wormholeApt },
  ];
  const outflowRateLimiterPairs: { type: string, outflowRateLimiter: OutflowLimiterModel }[] = [
    { type: coinTypes.cetus, outflowRateLimiter: outflowRateLimiters.cetus },
    { type: coinTypes.wormholeBtc, outflowRateLimiter: outflowRateLimiters.wormholeBtc },
    { type: coinTypes.wormholeSol, outflowRateLimiter: outflowRateLimiters.wormholeSol },
    { type: coinTypes.wormholeApt, outflowRateLimiter: outflowRateLimiters.wormholeApt },
  ];
  const incentiveRewardFactorPairs: { type: string, incentiveRewardFactor: IncentiveRewardFactor }[] = [
    { type: coinTypes.cetus, incentiveRewardFactor: incentiveRewardFactors.cetus },
    { type: coinTypes.wormholeBtc, incentiveRewardFactor: incentiveRewardFactors.wormholeBtc },
    { type: coinTypes.wormholeSol, incentiveRewardFactor: incentiveRewardFactors.wormholeSol },
    { type: coinTypes.wormholeApt, incentiveRewardFactor: incentiveRewardFactors.wormholeApt },
  ];
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: coinTypes.cetus, metadataId: coinMetadataIds.cetus },
    { type: coinTypes.wormholeBtc, metadataId: coinMetadataIds.wormholeBtc },
    { type: coinTypes.wormholeSol, metadataId: coinMetadataIds.wormholeSol },
    { type: coinTypes.wormholeApt, metadataId: coinMetadataIds.wormholeApt },
  ];
  const oraclePairs: { type: string, pythPriceObject: string  }[] = [
    { type: coinTypes.cetus, pythPriceObject: oracles.cetus.pythPriceObjectId },
    { type: coinTypes.wormholeBtc, pythPriceObject: oracles.wormholeBtc.pythPriceObjectId },
    { type: coinTypes.wormholeSol, pythPriceObject: oracles.wormholeSol.pythPriceObjectId },
    { type: coinTypes.wormholeApt, pythPriceObject: oracles.wormholeApt.pythPriceObjectId },
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
  // add outflow rate limiters
  outflowRateLimiterPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(txBlock, pair.outflowRateLimiter, pair.type);
  });
  // add incentive reward factors
  incentiveRewardFactorPairs.forEach(pair => {
    protocolTxBuilder.setIncentiveRewardFactor(txBlock, pair.incentiveRewardFactor, pair.type)
  });
  // register pyth price objects
  oraclePairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.pythPriceObject, pair.type);
  });
}

const tx = new SuiTxBlock();
addNewAssets(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error).finally(() => process.exit(0));
