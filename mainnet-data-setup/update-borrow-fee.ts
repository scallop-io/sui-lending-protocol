import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  protocolTxBuilder,
  BorrowFee,
} from '../contracts/protocol';
import { borrowFees } from './borrow-fee';
import { coinTypes } from './chain-data';
import { buildMultiSigTx } from './multi-sig';


export const updateBorrowFee = () => {
  const suiTxBlock = new SuiTxBlock();

  const borrowFeePairs: { type: string, borrowFee: BorrowFee }[] = [
    {type: coinTypes.nativeUsdc, borrowFee: borrowFees.nativeUsdc},
  ];

  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(suiTxBlock, pair.borrowFee, pair.type);
  });

  return buildMultiSigTx(suiTxBlock);
}

updateBorrowFee().then(console.log).catch(console.error).finally(() => process.exit(0));
