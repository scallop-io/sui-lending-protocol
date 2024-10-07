import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  pythRuleTxBuilder,
} from 'contracts/sui_x_oracle/pyth_rule';
import {
  oracles,
} from './asset-oracles';
import {
  coinTypes,
} from './chain-data';
import {buildMultiSigTx} from "./multi-sig";

export const registerPythPriceObject = () => {
  const tx = new SuiTxBlock();

  const pairs = [
    { coinType: coinTypes.wormholeBtc, priceObject: oracles.wormholeBtc.pythPriceObjectId },
    { coinType: coinTypes.wormholeSol, priceObject: oracles.wormholeSol.pythPriceObjectId },
  ];
  pairs.forEach(pair => {
    pythRuleTxBuilder.registerPythPriceInfoObject(tx, pair.priceObject, pair.coinType);
  });
  return buildMultiSigTx(tx);
}

registerPythPriceObject().then(console.log);