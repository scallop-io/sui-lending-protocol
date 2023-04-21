import path from "path";
import dotenv from "dotenv";
import { NetworkType } from "@scallop-dao/sui-kit";
import { ScallopSui } from "@scallop-dao/scallop-sui";
import { publishPackage } from "./publish-package";
import { dumpObjectIds } from "./dump-object-ids";
import { parseOpenObligationResponse } from "./parse-open-obligation-response";
import { writeAsJson } from "./write-as-json";

dotenv.config();

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const secretKey = process.env.SECRET_KEY || '';
  const networkType = (process.env.SUI_NETWORK_TYPE || 'devnet') as NetworkType;
  const packagePath = path.join(__dirname, '../query');
  const publishResult = await publishPackage(packagePath, secretKey, networkType);
  const objectIds = dumpObjectIds(publishResult);

  await delay(3000);

  const scallopSui = new ScallopSui({
    packageId: objectIds.packageData.packageId,
    marketId: objectIds.marketData.marketId,
    coinDecimalsRegistryId: objectIds.marketData.CoinDecimalsRegistryId,
    adminCapId: objectIds.marketData.adminCapId,
    priceFeedCapId: objectIds.oracleData.priceFeedCapId,
    priceFeedsId: objectIds.oracleData.priceFeedHolderId,
    suiConfig: { secretKey, networkType }
  });
  const txBuilder = scallopSui.createTxBuilder();

  // init market
  txBuilder.initMarketForTest(
    objectIds.testCoinData.usdc.treasuryId,
    objectIds.testCoinData.usdc.metadataId,
    objectIds.testCoinData.eth.metadataId
  );
  txBuilder.suiTxBlock.txBlock.setGasBudget(3 * 10 ** 9);
  const initResult = await scallopSui.submitTxn(txBuilder);
  console.log(initResult)

  await delay(3000);

  // open obligation and add collateral
  const ethCoinType = `${objectIds.packageData.packageId}::eth::ETH`;
  const res = await scallopSui.openObligationAndAddCollateral(100, ethCoinType)
  const obligationData = parseOpenObligationResponse(res);

  // Write the object ids to a file in json format
  writeAsJson({...objectIds, obligationData }, 'object-ids.json');
}

setup();
