import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
    protocolTxBuilder,
} from '../contracts/protocol';
import { coinTypes } from './chain-data';
import { suiKit } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';
import { MinCollaterals } from './min-collateral';


export const updateMinCollateral = async () => {
    const suiTxBlock = new SuiTxBlock();

    const minCollateralList: { type: string, min: number }[] = Object.keys(MinCollaterals).map(
        (key) => ({ type: (coinTypes as any)[key], min: (MinCollaterals as any)[key] })
    );

    minCollateralList.forEach(pair => {
        protocolTxBuilder.updateMinCollateral(suiTxBlock, pair.min, pair.type);
    });

    const txBytes = await buildMultiSigTx(suiTxBlock);
    const resp = await suiKit.client().dryRunTransactionBlock({
        transactionBlock: txBytes
    })
    console.log(resp.effects.status);
    return txBytes
}

updateMinCollateral().then(console.log).catch(console.error).finally(() => process.exit(0));
