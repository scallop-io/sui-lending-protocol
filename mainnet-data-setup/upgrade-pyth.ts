import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import {
  pythRuleTxBuilder,
  pythRuleStructType,
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

export const updateXOracle = (tx: SuiTxBlock) => {
  updateRulesForXOracle(tx);
  registerPythPriceObject(tx);
}

export const updateRulesForXOracle = (tx: SuiTxBlock) => {
  const oldPythRule = '0xaac1fdb607b884cc256c59dc307bb78b6ba95b97e22d4415fe87ad99689ea462::rule::Rule';
  xOracleTxBuilder.removePrimaryPriceUpdateRule(tx, oldPythRule);
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleStructType);
}

export const registerPythPriceObject = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: coinTypes.sui, priceObject: oracles.sui.pythPriceObjectId },
    { coinType: coinTypes.wormholeUsdc, priceObject: oracles.wormholeUsdc.pythPriceObjectId },
    { coinType: coinTypes.wormholeUsdt, priceObject: oracles.wormholeUsdt.pythPriceObjectId },
    { coinType: coinTypes.wormholeSol, priceObject: oracles.wormholeSol.pythPriceObjectId },
    { coinType: coinTypes.wormholeEth, priceObject: oracles.wormholeEth.pythPriceObjectId },
    { coinType: coinTypes.wormholeBtc, priceObject: oracles.wormholeBtc.pythPriceObjectId },
    { coinType: coinTypes.wormholeApt, priceObject: oracles.wormholeApt.pythPriceObjectId },
    { coinType: coinTypes.cetus, priceObject: oracles.cetus.pythPriceObjectId },
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
}

const tx = new SuiTxBlock();
updateXOracle(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error).finally(() => process.exit(0));
