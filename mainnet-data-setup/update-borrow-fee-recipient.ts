import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
} from '../contracts/protocol';
import { buildMultiSigTx, MULTI_SIG_ADDRESS } from './multi-sig';


export const updateBorrowFeeRecipient = () => {
  const suiTxBlock = new SuiTxBlock();

  protocolTxBuilder.updateBorrowFeeRecipient(suiTxBlock, MULTI_SIG_ADDRESS);


  return buildMultiSigTx(suiTxBlock);
}

updateBorrowFeeRecipient().then(console.log).catch(console.error).finally(() => process.exit(0));
