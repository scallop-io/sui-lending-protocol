import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
    protocolTxBuilder,
} from '../contracts/protocol';
import { coinTypes } from './chain-data';
import { suiKit } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';
import { ApmThresholds } from './apm-threshold';


export const updateApmThreshold = async () => {
    const suiTxBlock = new SuiTxBlock();

    const apmThresholdsList: { type: string, min: number }[] = Object.keys(ApmThresholds).map(
        (key) => ({ type: (coinTypes as any)[key], min: (ApmThresholds as any)[key] })
    );

    apmThresholdsList.forEach(pair => {
        protocolTxBuilder.setApmThreshold(suiTxBlock, pair.min, pair.type);
    });

    const txBytes = await buildMultiSigTx(suiTxBlock);
    const resp = await suiKit.client().dryRunTransactionBlock({
        transactionBlock: txBytes
    })
    console.log(resp.effects.status);
    return txBytes
}

updateApmThreshold().then(console.log).catch(console.error).finally(() => process.exit(0));
