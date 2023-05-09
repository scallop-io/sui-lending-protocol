import { SuiTxBlock } from "@scallop-io/sui-kit"
import { updatePrice } from "./oracle-price"
import { testCoinTypes } from "../contracts/test_coin"
import { suiKit } from "../sui-elements"

const main = async () => {
  const tx = new SuiTxBlock();
  await updatePrice(tx, testCoinTypes.btc);
  tx.txBlock.setGasBudget(10 ** 9);
  const res = await suiKit.signAndSendTxn(tx);
  console.log(res);
}

main().catch(console.error).finally(() => process.exit(0));
