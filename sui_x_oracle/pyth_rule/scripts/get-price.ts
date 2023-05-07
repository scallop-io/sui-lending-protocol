import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui.js"
import { SuiTxBlock } from "@scallop-io/sui-kit"
import { suiKit } from "../../ts-scripts/sui-kit"
import { getVaas } from "./get-vaas"

const pkgId = '0x011dc5ab7c7172c991d5d39978cb3c31b84dcb926fd2401a094992b65adae94d';

const warmholeStateId = '0x79ab4d569f7eb1efdcc1f25b532f8593cda84776206772e33b490694cb8fc07a';
const pythStateId = '0xe96526143f8305830a103331151d46063339f7a9946b50aaa0d704c8c04173e5';
const pythPriceInfoObjectId = '0x8899a5649db0099f3a685cf246ed2bd4224bc2078fcaf2c897268764df684d94';

const pythPriceId = 'f9c0172ba10dfa4d19088d94f5bf61d3b54d5bd7483a322a982e1373ee8ea31b';

(async () => {

  const vaaStart = Math.floor(Date.now() / 1000);
  const [vaa] = await getVaas([pythPriceId]);
  const vaaEnd = Math.floor(Date.now() / 1000);
  console.log(`getVaas took ${vaaEnd - vaaStart} seconds`);

  const suiTxBlock = new SuiTxBlock();
  let [fee] = suiTxBlock.splitSUIFromGas([1]);
  suiTxBlock.moveCall(
    `${pkgId}::test_pyth::get_pyth_price`,
    [
      warmholeStateId,
      pythStateId,
      pythPriceInfoObjectId,
      fee,
      suiTxBlock.pure([...Buffer.from(vaa, "base64")]),
      SUI_CLOCK_OBJECT_ID
    ]
  );
  suiTxBlock.txBlock.setGasBudget(10 ** 8);
  suiTxBlock.txBlock.setSender(suiKit.currentAddress());
  const buildTx = await suiTxBlock.txBlock.build({
    provider: suiKit.provider(),
  });
  let start = Math.floor(Date.now() / 1000);
  const res = await suiKit.getSigner().signAndExecuteTransactionBlock({
    transactionBlock: buildTx,
    options: {
      showEffects: true,
      showEvents: true
    }
  })
  console.log(res)
  let end = Math.floor(Date.now() / 1000);
  console.log(`Time elapsed: ${end - start} seconds`);

  // const res: any = await suiKit.signAndSendTxn(suiTxBlock);
  // console.log(res.events[1])
})();
