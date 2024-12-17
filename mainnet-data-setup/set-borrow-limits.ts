import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
    protocolTxBuilder,
} from '../contracts/protocol';
import { coinTypes } from './chain-data';
import { BorrowLimits } from './borrow-limits';
import { suiKit } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';


export const updateBorrowLimits = async () => {
    const suiTxBlock = new SuiTxBlock();

    const borrowLimitList: { type: string, limit: number }[] = [
        { type: coinTypes.deep, limit: BorrowLimits.deep },
    ];

    borrowLimitList.forEach(pair => {
        protocolTxBuilder.setBorrowLimit(suiTxBlock, pair.limit, pair.type);
    });

    const txBytes = await buildMultiSigTx(suiTxBlock);
    const resp = await suiKit.provider().dryRunTransactionBlock({
        transactionBlock: txBytes
    })
    console.log(resp.effects.status);
    return txBytes
}

updateBorrowLimits().then(console.log).catch(console.error).finally(() => process.exit(0));
