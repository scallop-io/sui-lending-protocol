import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { riskModels } from './risk-models';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { SupplyLimits } from './supply-limits';
import { borrowFees } from './borrow-fee';
import { FlashloanFees } from './flashloan-fees';
import { incentiveRewardFactors } from './incentive-reward-factors';

import { pythRuleTxBuilder } from 'contracts/sui_x_oracle/pyth_rule';
import { oracles } from './asset-oracles';

import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';

async function addUsdcPool() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.addRiskModel(tx, riskModels.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.addInterestModel(tx, interestModels.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees.nativeUsdc, coinTypes.nativeUsdc);
  protocolTxBuilder.setIncentiveRewardFactor(tx, incentiveRewardFactors.nativeUsdc, coinTypes.nativeUsdc);

  pythRuleTxBuilder.registerPythPriceInfoObject(tx, oracles.nativeUsdc.pythPriceObjectId, coinTypes.nativeUsdc);

  protocolTxBuilder.setBaseAssetActiveState(tx, false, coinTypes.nativeUsdc);
  protocolTxBuilder.setCollateralActiveState(tx, false, coinTypes.nativeUsdc);

  return buildMultiSigTx(tx);
}

addUsdcPool().then(console.log);