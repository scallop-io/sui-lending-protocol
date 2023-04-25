import path from "path";
import { ScallopSui } from "@scallop-dao/scallop-sui";
import { secretKey, networkType, suiKit } from "./sui-kit-instance";
import { publishPackage } from "./publish-package";
import { dumpObjectIds } from "./dump-object-ids";
import { parseOpenObligationResponse } from "./parse-open-obligation-response";
import { parseInitMarketTransaction } from "./parse-init-market-transaction";
import { registerSwitchboardOracles } from "./register-switchboard-oracles";
import { writeAsJson } from "./write-as-json";

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const packagePath = path.join(__dirname, '../query');
  const publishResult = await publishPackage(packagePath, suiKit.getSigner());
  if (!publishResult.packageId) {
    console.log(publishResult.publishTxn);
    throw new Error('Failed to publish package');
  }

  const objectIds = await dumpObjectIds(publishResult);

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
  txBuilder.suiTxBlock.txBlock.setGasBudget(6 * 10 ** 9);
  console.log('init market...')
  const initResult = await scallopSui.submitTxn(txBuilder);
  console.log('init market result done!')
  const initMarketResult = await parseInitMarketTransaction(initResult);

  await delay(3000);

  // open obligation and add collateral
  console.log('open obligation and add collateral...')
  const ethCoinType = `${objectIds.packageData.packageId}::eth::ETH`;
  const res = await scallopSui.openObligationAndAddCollateral(100, ethCoinType)
  const obligationData = parseOpenObligationResponse(res);
  console.log('open obligation and add collateral done!')

  // register switchboard aggregators
  console.log('register switchboard oracles...')
  const registerRes = await registerSwitchboardOracles(
    objectIds.packageData.packageId,
    objectIds.switchboardRegistryData.registryCapId,
    objectIds.switchboardRegistryData.registryId,
    initMarketResult.switchboardData.ethAggregatorId,
    initMarketResult.switchboardData.usdcAggregatorId,
  );
  console.log(registerRes);
  console.log('register switchboard oracles done!');

  // Write the object ids to a file in json format
  console.log('write object ids to file: object-ids.json')
  writeAsJson({...objectIds, obligationData, switchboard: initMarketResult.switchboardData }, 'object-ids.json');
  console.log('write object ids to file done!')
}

setup();
