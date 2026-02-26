import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { buildMultiSigTx } from './multi-sig';

export const initMarketCoinPriceTable = async () => {
  const suiTxBlock = new SuiTxBlock();
  protocolTxBuilder.initMarketCoinPriceTable(suiTxBlock);
  return buildMultiSigTx(suiTxBlock);
}

initMarketCoinPriceTable().then(console.log).catch(console.error).finally(() => process.exit(0));
