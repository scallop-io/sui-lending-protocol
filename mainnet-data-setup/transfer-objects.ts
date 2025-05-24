import { buildMultiSigTx } from './multi-sig';
import { SuiTxBlock } from '@scallop-io/sui-kit';

transferObjects().then(console.log);
async function transferObjects() {
  const objects = [
    '0x6fe6200624299584c2a96cdcdba6461bd07fe42d2640efb549a15d947f0a0521',
  ]
  const recipient = '0x473c5b346a779b7d6271a94fccc4c0d75c380a9f478cd7afaec79127a715c519';

  const tx = new SuiTxBlock();
  tx.transferObjects(objects, recipient);
  return buildMultiSigTx(tx);
}
