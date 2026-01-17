import { SuiTxBlock } from '@scallop-io/sui-kit';
import { protocolTxBuilder } from 'contracts/protocol';
import { suiKit } from 'sui-elements';

async function freezeProtocol() {
    const tx = new SuiTxBlock();

    protocolTxBuilder.freezeProtocol(tx);

    const resp = await suiKit.signAndSendTxn(tx);
    console.log(resp)
}

freezeProtocol().then(console.log);
