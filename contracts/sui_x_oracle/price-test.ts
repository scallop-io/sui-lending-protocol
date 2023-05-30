import { SuiTxBlock } from "@scallop-io/sui-kit"
import { testCoinTypes } from 'contracts/test_coin'
import { updatePrice } from "./oracle-price"
import { suiKit } from "sui-elements"

async function main() {

  let tx = new SuiTxBlock();

  tx.txBlock.setGasBudget(2 * 10 ** 9);
  await updatePrice(tx, testCoinTypes.btc);
  // await updatePrice(tx, testCoinTypes.eth);
  // await updatePrice(tx, testCoinTypes.usdc);
  // await updatePrice(tx, testCoinTypes.usdt);
  // await updatePrice(tx, '0x2::sui::SUI');
  suiKit.signAndSendTxn(tx).then(console.log).catch(console.error).finally(() => process.exit(0));
}

main()