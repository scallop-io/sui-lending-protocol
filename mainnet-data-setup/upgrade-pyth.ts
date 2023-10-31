import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import {
  pythRuleTxBuilder,
  pythRuleStructType,
  publishResult as pythPublishResult,
} from 'contracts/sui_x_oracle/pyth_rule';
import {
  oracles,
} from './asset-oracles';
import {
  xOracleTxBuilder
} from 'contracts/sui_x_oracle/x_oracle';
import {
  coinTypes,
} from './chain-data';
import {buildMultiSigTx, MULTI_SIG_ADDRESS} from "./multi-sig";

export const updatePythRuleForXOracle = () => {
  const tx = new SuiTxBlock();
  const oldPythPkgId = '0x9f116b10b6c166901b2d4f46e7d0f5bb68424b9428c43774517d3ea6928a4040';
  const oldPythRule = `${oldPythPkgId}::rule::Rule`;
  xOracleTxBuilder.removePrimaryPriceUpdateRule(tx, oldPythRule);
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleStructType);
  return buildMultiSigTx(tx);
}

export const migrateToMultiSig = () => {
  const tx = new SuiTxBlock();
  tx.transferObjects([pythPublishResult.upgradeCapId, pythPublishResult.pythRegistryCapId], MULTI_SIG_ADDRESS);
  return suiKit.signAndSendTxn(tx);
}

export const registerPythPriceObject = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: coinTypes.sui, priceObject: oracles.sui.pythPriceObjectId },
    { coinType: coinTypes.haSui, priceObject: oracles.sui.pythPriceObjectId },
    { coinType: coinTypes.afSui, priceObject: oracles.sui.pythPriceObjectId },
    { coinType: coinTypes.cetus, priceObject: oracles.cetus.pythPriceObjectId },
    { coinType: coinTypes.wormholeUsdc, priceObject: oracles.wormholeUsdc.pythPriceObjectId },
    { coinType: coinTypes.wormholeUsdt, priceObject: oracles.wormholeUsdt.pythPriceObjectId },
    { coinType: coinTypes.wormholeEth, priceObject: oracles.wormholeEth.pythPriceObjectId },
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
}


updatePythRuleForXOracle().then(console.log);