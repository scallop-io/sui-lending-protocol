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

async function addNewPool_haedal() {
  const tx = new SuiTxBlock();
  const coin = 'haedal';
  const dustCoinId = '0xd63a0ac2bf7bc0a79e5b2bada85a9eb9b7e3e88a1a8c6b8b692b86bd4d168ecb'; // This is used to keep a minimum amount of the coin in the pool
  const coinType = coinTypes[coin];
  protocolTxBuilder.addInterestModel(tx, interestModels[coin], coinType);
  protocolTxBuilder.addLimiter(tx, outflowRateLimiters[coin], coinType);
  protocolTxBuilder.setSupplyLimit(tx, SupplyLimits[coin], coinType);
  protocolTxBuilder.setBorrowLimit(tx, BorrowLimits[coin], coinType);
  protocolTxBuilder.updateBorrowFee(tx, borrowFees[coin], coinType);
  protocolTxBuilder.setFlashloanFee(tx, FlashloanFees[coin], coinType);
  protocolTxBuilder.updateIsolatedAssetStatus(tx, true, coinType);

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

addNewPool_haedal().then(console.log);