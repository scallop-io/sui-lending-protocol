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
    {type: coinTypes.sui, borrowFee: borrowFees.sui},
    {type: coinTypes.afSui, borrowFee: borrowFees.afSui},
    {type: coinTypes.haSui, borrowFee: borrowFees.haSui},
    {type: coinTypes.vSui, borrowFee: borrowFees.vSui},
    {type: coinTypes.cetus, borrowFee: borrowFees.cetus},
    {type: coinTypes.wormholeUsdc, borrowFee: borrowFees.wormholeUsdc},
    {type: coinTypes.wormholeUsdt, borrowFee: borrowFees.wormholeUsdt},
    {type: coinTypes.wormholeEth, borrowFee: borrowFees.wormholeEth},
    {type: coinTypes.sca, borrowFee: borrowFees.sca},
  ];

  borrowFeePairs.forEach(pair => {
    protocolTxBuilder.updateBorrowFee(suiTxBlock, pair.borrowFee, pair.type);
  });

  return buildMultiSigTx(suiTxBlock);
}

updateBorrowFee().then(console.log).catch(console.error).finally(() => process.exit(0));
