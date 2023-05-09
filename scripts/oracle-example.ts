import { SuiTxBlock } from "@scallop-io/sui-kit"
import { updatePrice } from "./oracle-price"
import { testCoinTypes } from "../test_coin"
import { suiKit } from "./sui-kit-instance"

const main = async () => {
  const tx = new SuiTxBlock();
  await updatePrice(tx, testCoinTypes.eth);
  tx.txBlock.setGasBudget(10 ** 9);
  const res = await suiKit.signAndSendTxn(tx);
  console.log(res);
}

main().catch(console.error).finally(() => process.exit(0));
