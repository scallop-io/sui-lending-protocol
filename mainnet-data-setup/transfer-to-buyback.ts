import { SuiTxBlock } from '@scallop-io/sui-kit';
import { buildMultiSigTx } from './multi-sig';


export const transferToBuyback = () => {
  const suiTxBlock = new SuiTxBlock();

  const objects = [
    '0xf2b3c4c28b4054ceb096668c25853dcdaec6bd1977abb79376bb7bdce1f58b13',
    '0xf055c01edfe9ba4dedeb2071f6b36926a79be004956f1213b4c6095e5cbf91fb'
  ];
  const BuyBackAddress = '0x5f0e70f77404a01e4437f850616d0a31e155fb14a2f276b8028d7423e26665e2';
  suiTxBlock.transferObjects(objects, BuyBackAddress);

  return buildMultiSigTx(suiTxBlock);
}

transferToBuyback().then(console.log).catch(console.error).finally(() => process.exit(0));
