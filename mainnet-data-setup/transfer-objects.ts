import { buildMultiSigTx } from './multi-sig';
import { SuiTxBlock } from '@scallop-io/sui-kit';

transferObjects().then(console.log);
async function transferObjects() {
  const objects = [
    '0xcd8f2b7c4e82f618c9979dacd3cea0dcf1939637d60ffe23413a53153895cfe5',
  ]
  const recipient = '0x66b12e98c51d86f0823c39b5555c557d6044822abe5cdb68f0fe761e5bffed08';

  const tx = new SuiTxBlock();
  tx.transferObjects(objects, recipient);
  return buildMultiSigTx(tx);
}
