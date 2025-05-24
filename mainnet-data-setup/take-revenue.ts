import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { coinTypes } from './chain-data';


export const takeRevenue = () => {
  const suiTxBlock = new SuiTxBlock();



  protocolTxBuilder.takeRevenue(suiTxBlock, 89007e9, coinTypes.sui);

  return buildMultiSigTx(suiTxBlock);
}

takeRevenue().then(console.log).catch(console.error).finally(() => process.exit(0));
