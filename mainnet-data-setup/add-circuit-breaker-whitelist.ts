import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { suiKit } from 'sui-elements';
import { buildMultiSigTx } from './multi-sig';

async function addCircuitBreakerWhitelist() {
    const tx = new SuiTxBlock();
    const address = "<PASTE_ADDRESS_HERE>";
    protocolTxBuilder.addPauseAuthorityRegistry(
        tx,
        address,
    );
    const txBytes = await buildMultiSigTx(tx);
    const resp = await suiKit.client().dryRunTransactionBlock({
        transactionBlock: txBytes
    })
    console.log(resp.effects.status);
    console.log(resp.balanceChanges);
    return txBytes;
}

addCircuitBreakerWhitelist().then(console.log);
