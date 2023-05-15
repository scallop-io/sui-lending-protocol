import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { protocolTxBuilder } from '../contracts/protocol';

export const addWhitelistForTest = () => {
    const tx = new SuiTxBlock();
    const targetAddresses = '';
    protocolTxBuilder.addWhitelistAddress(
        tx,
        targetAddresses,
    );
    return suiKit.signAndSendTxn(tx);
}

addWhitelistForTest().then(console.log).catch(console.error).finally(() => process.exit(0));