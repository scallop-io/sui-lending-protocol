import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit } from './sui-kit-instance';

// split the gas coin into 10 coins with 10^11 SUI each
// and transfer them to the current address
export const splitCoins = async () => {
  const tx = new SuiTxBlock();
  // generate an array of numbers
  const amounts = Array.from({ length: 10 }, () => 10 ** 11);
  const coins = tx.splitSUIFromGas(amounts);
  const coinObjects = Array.from({ length: 10 }, (_, index) => coins[index]);
  tx.transferObjects(coinObjects, suiKit.currentAddress());
  return suiKit.signAndSendTxn(tx);
}

splitCoins().then(console.log)
