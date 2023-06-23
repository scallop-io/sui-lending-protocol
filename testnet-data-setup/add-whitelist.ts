import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { protocolTxBuilder } from '../contracts/protocol';

export const addWhitelistForTest = async () => {
    const tx = new SuiTxBlock();
    const addr = '0xbe379359ac6e9d0fc0b867f147f248f1c2d9fc019a9a708adfcbe15fc3130c18';
    protocolTxBuilder.addWhitelistAddress(tx, addr)
    return suiKit.signAndSendTxn(tx);
}

addWhitelistForTest().then(console.log).catch(console.error).finally(() => process.exit(0));
