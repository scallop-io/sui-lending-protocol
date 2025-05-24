import { SuiTxBlock } from '@scallop-io/sui-kit';
import { buildMultiSigTx } from './multi-sig';


export const transferToBuyback = () => {
  const suiTxBlock = new SuiTxBlock();

  const objects = [
    '0x06bd46d0204b7faba458dc2342e08fc5008993d5bef84e0f1d87fa3e1728b319',
  ];
  const BuyBackAddress = '0x473c5b346a779b7d6271a94fccc4c0d75c380a9f478cd7afaec79127a715c519';
  suiTxBlock.transferObjects(objects, BuyBackAddress);

  return buildMultiSigTx(suiTxBlock);
}

transferToBuyback().then(console.log).catch(console.error).finally(() => process.exit(0));
