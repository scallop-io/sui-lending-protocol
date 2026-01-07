import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { suiKit } from 'sui-elements';

async function addCircuitBreakerWhitelist() {
    const address = "";

    const tx = new SuiTxBlock();
    protocolTxBuilder.addPauseAuthorityRegistry(
        tx,
        address,
    );
    const resp = await suiKit.signAndSendTxn(tx);
    console.log(resp)
}

addCircuitBreakerWhitelist().then(console.log);
