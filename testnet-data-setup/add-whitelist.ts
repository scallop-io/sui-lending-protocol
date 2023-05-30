import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from '../sui-elements';
import { protocolTxBuilder } from '../contracts/protocol';

export const addWhitelistForTest = (tx: SuiTxBlock) => {
    protocolTxBuilder.addWhitelistAddress(tx, suiKit.currentAddress())
}

// addWhitelistForTest().then(console.log).catch(console.error).finally(() => process.exit(0));
