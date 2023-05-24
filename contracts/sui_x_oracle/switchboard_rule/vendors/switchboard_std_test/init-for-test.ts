import * as path from "path";
import { SwitchboardTestTxBuilder } from "./typescript/tx-builder";
import { SuiTxBlock } from "@scallop-io/sui-kit";
import { suiKit, networkType } from "sui-elements";

const main = async () => {
  const tx = new SuiTxBlock();
  const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
  const txBuilder = new SwitchboardTestTxBuilder(publishResult.packageId);
  for(let i = 0; i < 5; i++) {
    txBuilder.createAggregator(tx);
  }
  tx.txBlock.setGasBudget(10 ** 9);
  const res = await suiKit.signAndSendTxn(tx);
  console.log(res);
}

main().catch(console.error).finally(() => process.exit(0));
