import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { protocolTxBuilder } from '../contracts/protocol';

export const addWhitelistForTest = async () => {
    const tx = new SuiTxBlock();
    const addr = '0x5e813e4c2504b76bfbef802411c11d1688b5d35f7a5c209e9eb4eb78780b322a';
    protocolTxBuilder.addWhitelistAddress(tx, addr)
    return suiKit.signAndSendTxn(tx);
}

addWhitelistForTest().then(console.log).catch(console.error).finally(() => process.exit(0));
