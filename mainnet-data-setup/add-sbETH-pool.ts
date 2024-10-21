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

import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';

import { coinTypes, coinMetadataIds } from './chain-data';
import { buildMultiSigTx } from './multi-sig';

async function addSbEthPool() {
  const tx = new SuiTxBlock();
  protocolTxBuilder.addRiskModel(tx, riskModels.sbEth, coinTypes.sbEth);
  protocolTxBuilder.addInterestModel(tx, interestModels.sbEth, coinTypes.sbEth);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters.sbEth, coinTypes.sbEth);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits.sbEth, coinTypes.sbEth);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees.sbEth, coinTypes.sbEth);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees.sbEth, coinTypes.sbEth);
  protocolTxBuilder.setIncentiveRewardFactor(tx, incentiveRewardFactors.sbEth, coinTypes.sbEth);

  pythRuleTxBuilder.registerPythPriceInfoObject(tx, oracles.sbEth.pythPriceObjectId, coinTypes.sbEth);

  decimalsRegistryTxBuilder.registerDecimals(tx, coinMetadataIds.sbEth, coinTypes.sbEth);

  return buildMultiSigTx(tx);
}

addSbEthPool().then(console.log);