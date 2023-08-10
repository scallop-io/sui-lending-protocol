import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import {
  pythRuleTxBuilder,
  pythRuleStructType,
  pythOracleData,
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

export const initXOracle = (tx: SuiTxBlock) => {
  // addRulesForXOracle(tx);
  registerPythPriceObject(tx);
}

export const addRulesForXOracle = (tx: SuiTxBlock) => {
  xOracleTxBuilder.addPrimaryPriceUpdateRule(tx, pythRuleStructType);
}

export const registerPythPriceObject = (tx: SuiTxBlock) => {

  const pairs = [
    { coinType: coinTypes.wormholeUsdc, priceObject: oracles.wormholeUsdc.pythPriceObjectId },
    { coinType: coinTypes.sui, priceObject: oracles.sui.pythPriceObjectId }
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
}

const tx = new SuiTxBlock();
registerPythPriceObject(tx);
suiKit.signAndSendTxn(tx).then(console.log).catch(console.error).finally(() => process.exit(0));