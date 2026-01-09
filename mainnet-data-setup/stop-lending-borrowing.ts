import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
    protocolTxBuilder,
} from '../contracts/protocol';
import { coinTypes } from './chain-data';
import { BorrowLimits } from './borrow-limits';
import { suiKit } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';
import { SupplyLimits } from './supply-limits';

export const stopLendingBorrow = async () => {
    const suiTxBlock = new SuiTxBlock();
    const supplyLimitList: { type: string, limit: number }[] = [];
    for(const key of Object.keys(coinTypes)) {
        const coinType = coinTypes[key as keyof typeof coinTypes];
        const supplyLimit = SupplyLimits[key as keyof typeof SupplyLimits];
        if (supplyLimit !== undefined) {
            supplyLimitList.push({ type: coinType, limit: 0 });
        }
    }

    supplyLimitList.forEach(pair => {
        protocolTxBuilder.setSupplyLimit(suiTxBlock, pair.limit, pair.type);
    });

    const borrowLimitList: { type: string, limit: number }[] = [];
    for(const key of Object.keys(coinTypes)) {
        const coinType = coinTypes[key as keyof typeof coinTypes];
        const borrowLimit = BorrowLimits[key as keyof typeof BorrowLimits];
        if (borrowLimit !== undefined) {
            borrowLimitList.push({ type: coinType, limit: 0 });
        }
    }
    
    borrowLimitList.forEach(pair => {
        protocolTxBuilder.setBorrowLimit(suiTxBlock, pair.limit, pair.type);
    });

    const txBytes = await buildMultiSigTx(suiTxBlock);
    const resp = await suiKit.client().dryRunTransactionBlock({
        transactionBlock: txBytes
    })
    console.log(resp.effects.status);
    return txBytes
}

stopLendingBorrow().then(console.log).catch(console.error).finally(() => process.exit(0));
