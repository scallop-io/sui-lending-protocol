import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { buildMultiSigTx } from './multi-sig';
import { coinTypes } from './chain-data';


export const takeRevenue = () => {
  const suiTxBlock = new SuiTxBlock();



  protocolTxBuilder.takeRevenue(suiTxBlock, 50000e6, coinTypes.wormholeUsdc);
  protocolTxBuilder.takeRevenue(suiTxBlock, 62500e9, coinTypes.sui);

  return buildMultiSigTx(suiTxBlock);
}

takeRevenue().then(console.log).catch(console.error).finally(() => process.exit(0));
