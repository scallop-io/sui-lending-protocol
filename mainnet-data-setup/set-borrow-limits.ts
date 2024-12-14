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
        { type: coinTypes.sui, limit: BorrowLimits.sui },
        { type: coinTypes.afSui, limit: BorrowLimits.afSui },
        { type: coinTypes.vSui, limit: BorrowLimits.vSui },
        { type: coinTypes.haSui, limit: BorrowLimits.haSui },
        { type: coinTypes.nativeUsdc, limit: BorrowLimits.nativeUsdc },
        { type: coinTypes.sbEth, limit: BorrowLimits.sbEth },
        { type: coinTypes.wormholeEth, limit: BorrowLimits.wormholeEth },
        { type: coinTypes.cetus, limit: BorrowLimits.cetus },
        { type: coinTypes.wormholeSol, limit: BorrowLimits.wormholeSol },
        { type: coinTypes.wormholeBtc, limit: BorrowLimits.wormholeBtc },
        { type: coinTypes.wormholeUsdc, limit: BorrowLimits.wormholeUsdc },
        { type: coinTypes.wormholeUsdt, limit: BorrowLimits.wormholeUsdt },
        { type: coinTypes.sca, limit: BorrowLimits.sca },
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
