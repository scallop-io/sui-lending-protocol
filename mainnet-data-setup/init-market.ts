import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  IncentiveRewardFactor
} from '../contracts/protocol';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { incentiveRewardFactors } from './incentive-reward-factors';
import { coinTypes } from './chain-data';
import { suiKit } from 'sui-elements';

initMarket().then(console.log).catch(console.error).finally(() => process.exit(0));

async function initMarket() {
  const suiTxBlock = new SuiTxBlock();

  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.sui, riskModel: riskModels.sui },
    { type: coinTypes.wormholeUsdc, riskModel: riskModels.wormholeUsdc },
    { type: coinTypes.wormholeUsdt, riskModel: riskModels.wormholeUsdt },
  ];

  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sui, interestModel: interestModels.sui },
    { type: coinTypes.wormholeUsdc, interestModel: interestModels.wormholeUsdc },
    { type: coinTypes.wormholeUsdt, interestModel: interestModels.wormholeUsdt },
  ];

  const outflowLimitPairs: { type: string, outflowLimit: OutflowLimiterModel }[] = [
    { type: coinTypes.sui, outflowLimit: outflowRateLimiters.sui },
    { type: coinTypes.wormholeUsdc, outflowLimit: outflowRateLimiters.wormholeUsdc },
    { type: coinTypes.wormholeUsdt, outflowLimit: outflowRateLimiters.wormholeUsdt },
  ];

  const incentiveRewardFactorPairs: { type: string, incentiveRewardFactor: IncentiveRewardFactor }[] = [
    { type: coinTypes.sui, incentiveRewardFactor: incentiveRewardFactors.sui },
    { type: coinTypes.wormholeUsdc, incentiveRewardFactor: incentiveRewardFactors.wormholeUsdc },
    { type: coinTypes.wormholeUsdt, incentiveRewardFactor: incentiveRewardFactors.wormholeUsdt }
  ];

  riskModelPairs.forEach(pair => {
    protocolTxBuilder.addRiskModel(suiTxBlock, pair.riskModel, pair.type);
  });
  interestModelPairs.forEach(pair => {
    protocolTxBuilder.addInterestModel(suiTxBlock, pair.interestModel, pair.type);
  });
  outflowLimitPairs.forEach(pair => {
    protocolTxBuilder.addLimiter(suiTxBlock, pair.outflowLimit, pair.type);
  });
  incentiveRewardFactorPairs.forEach(pair => {
    protocolTxBuilder.setIncentiveRewardFactor(suiTxBlock, pair.incentiveRewardFactor, pair.type)
  });

  return suiKit.signAndSendTxn(suiTxBlock);
}
