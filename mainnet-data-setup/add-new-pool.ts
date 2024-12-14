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

async function addNewPool_DEEP() {
  const tx = new SuiTxBlock();
  const coin = 'deep';
  const dustCoinId = '0x186ee7ad0a9a8668fa62e4d524d8738303463b6d03b30f106c54594f0ed9263b'; // This is used to keep a minimum amount of the coin in the pool
  const coinType = coinTypes[coin];
  protocolTxBuilder.addInterestModel(tx, interestModels[coin], coinType);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters[coin], coinType);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits[coin], coinType);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees[coin], coinType);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees[coin], coinType);
  protocolTxBuilder.setIncentiveRewardFactor(tx, incentiveRewardFactors[coin], coinType);

  pythRuleTxBuilder.registerPythPriceInfoObject(tx, oracles[coin].pythPriceObjectId, coinType);

  decimalsRegistryTxBuilder.registerDecimals(tx, coinMetadataIds[coin], coinType);

  // Burn dust to keep a minimum amount of the coin in the pool
  const dustToBurn = protocolTxBuilder.supplyBaseAsset(tx, dustCoinId, coinType);
  const voidAddress = '0x0';
  tx.transferObjects([dustToBurn], voidAddress);

  return buildMultiSigTx(tx);
}

async function addNewPool_FUD() {
  const tx = new SuiTxBlock();
  const coin = 'fud';
  const dustCoinId = '0x5a968bd1dcf38f0e13ede7da9af7de0e8d92f63952f017b5f5ed7ac86726b882'; // This is used to keep a minimum amount of the coin in the pool
  const coinType = coinTypes[coin];
  protocolTxBuilder.addInterestModel(tx, interestModels[coin], coinType);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters[coin], coinType);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits[coin], coinType);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees[coin], coinType);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees[coin], coinType);
  protocolTxBuilder.setIncentiveRewardFactor(tx, incentiveRewardFactors[coin], coinType);

  pythRuleTxBuilder.registerPythPriceInfoObject(tx, oracles[coin].pythPriceObjectId, coinType);

  decimalsRegistryTxBuilder.registerDecimals(tx, coinMetadataIds[coin], coinType);

  // Burn dust to keep a minimum amount of the coin in the pool
  const dustToBurn = protocolTxBuilder.supplyBaseAsset(tx, dustCoinId, coinType);
  const voidAddress = '0x0';
  tx.transferObjects([dustToBurn], voidAddress);

  return buildMultiSigTx(tx);
}

addNewPool_DEEP().then(console.log);