import { SuiTxBlock } from '@scallop-io/sui-kit';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { incentiveRewardFactors } from './incentive-reward-factors';
import { coinTypes, coinMetadataIds } from './chain-data';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  IncentiveRewardFactor,
} from '../contracts/protocol';
import {
  decimalsRegistryTxBuilder,
} from '../contracts/libs/coin_decimals_registry';

const addEthUsdt = (txBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.wormholeEth, riskModel: riskModels.wormholeEth },
    { type: coinTypes.wormholeUsdt, riskModel: riskModels.wormholeUsdt },
  ];
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.wormholeEth, interestModel: interestModels.wormholeEth },
    { type: coinTypes.wormholeUsdt, interestModel: interestModels.wormholeUsdt },
  ];
  const outflowRateLimiterPairs: { type: string, outflowRateLimiter: OutflowLimiterModel }[] = [
    { type: coinTypes.wormholeEth, outflowRateLimiter: outflowRateLimiters.wormholeEth },
    { type: coinTypes.wormholeUsdt, outflowRateLimiter: outflowRateLimiters.wormholeUsdt },
  ];
  const incentiveRewardFactorPairs: { type: string, incentiveRewardFactor: IncentiveRewardFactor }[] = [
    { type: coinTypes.wormholeEth, incentiveRewardFactor: incentiveRewardFactors.wormholeEth },
    { type: coinTypes.wormholeUsdt, incentiveRewardFactor: incentiveRewardFactors.wormholeUsdt },
  ];
  const decimalsPairs: { type: string, metadataId: string }[] = [
    { type: coinTypes.wormholeEth, metadataId: coinMetadataIds.wormholeEth },
    { type: coinTypes.wormholeUsdt, metadataId: coinMetadataIds.wormholeUsdt },
  ];

  decimalsPairs.forEach(pair => {
    decimalsRegistryTxBuilder.registerDecimals(
      txBlock,
      pair.metadataId,
      pair.type,
    );
  });
  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(
      txBlock,
      pair.riskModel,
      pair.type,
    );
  });
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(
      txBlock,
      pair.interestModel,
      pair.type,
    );
  });
  outflowRateLimiterPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(
      txBlock,
      pair.outflowRateLimiter,
      pair.type,
    );
  });
  incentiveRewardFactorPairs.forEach(pair => {
    protocolTxBuilder.setIncentiveRewardFactor(
      txBlock,
      pair.incentiveRewardFactor,
      pair.type,
    )
  });
}
