import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { interestModels } from './interest-models';
import { outflowRateLimiters } from './outflow-rate-limiters';
import { SupplyLimits } from './supply-limits';
import { borrowFees } from './borrow-fee';
import { FlashloanFees } from './flashloan-fees';

import { pythRuleStructType, pythRuleTxBuilder } from 'contracts/sui_x_oracle/pyth_rule';
import { oracles } from './asset-oracles';

import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';

import { coinTypes, coinMetadataIds } from './chain-data';
import { buildMultiSigTx } from './multi-sig';
import { BorrowLimits } from './borrow-limits';
import { suiKit } from 'sui-elements';
import { xOracleTxBuilder } from 'contracts/sui_x_oracle';
import { riskModels } from './risk-models';

async function addNewPool_haWal() {
  const tx = new SuiTxBlock();
  const coin = 'haWal';
  const dustCoinId = '0xd4be5cdd137a8b26a03c46de227d188c1e385edddf3743e465fc453323e0763e'; // This is used to keep a minimum amount of the coin in the pool
  const coinType = coinTypes[coin];
  protocolTxBuilder.addInterestModel(tx, interestModels[coin], coinType);
  protocolTxBuilder.addRiskModel(tx, riskModels[coin], coinType);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters[coin], coinType);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits[coin], coinType);
  protocolTxBuilder.setBorrowLimit(tx, BorrowLimits[coin], coinType);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees[coin], coinType);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees[coin], coinType);

  pythRuleTxBuilder.registerPythFeed(tx, oracles[coin].pythPriceObjectId, pythRuleTxBuilder.calculatePriceConfidenceTolerance(2), coinType);
  xOracleTxBuilder.addPrimaryPriceUpdateRuleV2(tx, coinType, pythRuleStructType);

  decimalsRegistryTxBuilder.registerDecimals(tx, coinMetadataIds[coin], coinType);

  // // Burn dust to keep a minimum amount of the coin in the pool
  const dustToBurn = protocolTxBuilder.supplyBaseAsset(tx, dustCoinId, coinType);
  const voidAddress = '0x0000000000000000000000000000000000000000000000000000000000000000';
  tx.transferObjects([dustToBurn], voidAddress);

  const txBytes = await buildMultiSigTx(tx);
  const resp = await suiKit.client().dryRunTransactionBlock({
      transactionBlock: txBytes
  })
  console.log(resp.effects.status);
  console.log(resp.balanceChanges);

  return txBytes;
}

addNewPool_haWal().then(console.log);