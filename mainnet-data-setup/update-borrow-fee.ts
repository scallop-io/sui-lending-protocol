import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import {
  protocolTxBuilder,
  BorrowFee,
} from '../contracts/protocol';
import { borrowFees } from './borrow-fee';
import { coinTypes } from './chain-data';


export const updateBorrowFee = () => {
  const suiTxBlock = new SuiTxBlock();

  const borrowFeePairs: { type: string, borrowFee: BorrowFee }[] = [
    {type: coinTypes.wormholeUsdc, borrowFee: borrowFees.wormholeUsdc},
  ];

  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(suiTxBlock, pair.borrowFee, pair.type);
  });

  return suiKit.signAndSendTxn(suiTxBlock);
}

updateBorrowFee().then(console.log).catch(console.error).finally(() => process.exit(0));
