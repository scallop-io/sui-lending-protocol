import { SuiTxBlock } from '@scallop-io/sui-kit';
import { riskModels } from './risk-models';
import { oracles } from './asset-oracles';
import { coinTypes } from './chain-data';
import {
  protocolTxBuilder,
  RiskModel,
  InterestModel,
  OutflowLimiterModel,
  IncentiveRewardFactor,
  BorrowFee,
} from '../contracts/protocol';
import { pythRuleTxBuilder } from '../contracts/sui_x_oracle';
import { interestModels } from './interest-models';
import { incentiveRewardFactors } from './incentive-reward-factors';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { MULTI_SIG_ADDRESS, buildMultiSigTx } from './multi-sig';
import { borrowFees } from './borrow-fee';
import { suiKit } from 'sui-elements';

const integrateSCA = async (txBlock: SuiTxBlock) => {
  const riskModelPairs: { type: string, riskModel: RiskModel }[] = [
    { type: coinTypes.sca, riskModel: riskModels.sca },
  ];
  const interestModelPairs: { type: string, interestModel: InterestModel }[] = [
    { type: coinTypes.sca, interestModel: interestModels.sca },
  ];
  const oraclePairs: { type: string, pythPriceObject: string  }[] = [
    { type: coinTypes.sca, pythPriceObject: oracles.sca.pythPriceObjectId },
  ];
  const outflowLimiterPairs: { type: string, outflowLimiter: OutflowLimiterModel }[] = [
    { type: coinTypes.sca, outflowLimiter: outflowRateLimiters.sca },
  ];
  const incentiveRewardFactorPairs: { type: string, incentiveRewardFactor: IncentiveRewardFactor }[] = [
    { type: coinTypes.sca, incentiveRewardFactor: incentiveRewardFactors.sca },
  ];
  const borrowFeePairs: { type: string, borrowFee: BorrowFee }[] = [
    { type: coinTypes.sca, borrowFee: borrowFees.sca },
  ];

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
  // add borrow fee
  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(txBlock, pair.borrowFee, pair.type);
  });

  txBlock.setSender(MULTI_SIG_ADDRESS)
  const bytes = await txBlock.build({ provider: suiKit.provider() })

  const res = await suiKit.provider().dryRunTransactionBlock({ transactionBlock: bytes })
  console.log(res)

  return buildMultiSigTx(txBlock);
}

integrateSCA(new SuiTxBlock()).then(console.log);