import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { dryRunTx } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';

async function whitelistAllowAll() {
    const tx = new SuiTxBlock();
    protocolTxBuilder.whitelistAllowAll(
        tx,
    );
    const txBytes = await buildMultiSigTx(tx);
    const resp = await dryRunTx(txBytes)
    console.log(resp.effects.status);
    console.log(resp.events);
    return txBytes
}

whitelistAllowAll().then(console.log);
