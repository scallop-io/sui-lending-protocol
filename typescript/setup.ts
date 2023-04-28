import path from "path";
import { ScallopSui } from "@scallop-dao/scallop-sui";
import { secretKey, networkType, suiKit } from "./sui-kit-instance";
import { initMarketForTest } from "./init-market";
import { publishProtocol } from "./publish-protocol";
import { parseOpenObligationResponse } from "./parse-open-obligation-response";
import { registerSwitchboardOracles } from "./register-switchboard-oracles";
import { writeAsJson } from "./write-as-json";

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const packagePath = path.join(__dirname, '../protocol');
  const protocolPublishResult = await publishProtocol(packagePath, suiKit.getSigner());
  if (!protocolPublishResult.packageData.packageId) {
    console.log(protocolPublishResult.txn);
    throw new Error('Failed to publish package');
  }

  await delay(3000);

  // init market
  console.log('init market...')
  const initMarketResult = await initMarketForTest(protocolPublishResult);
  console.log('init market result done!')

  const scallopSui = new ScallopSui({
    packageId: protocolPublishResult.packageData.packageId,
    marketId: protocolPublishResult.marketData.marketId,
    coinDecimalsRegistryId: protocolPublishResult.marketData.coinDecimalsRegistryId,
    adminCapId: protocolPublishResult.marketData.adminCapId,
    priceFeedCapId: '',
    priceFeedsId: '',
    suiConfig: { secretKey, networkType }
  });

  // open obligation and add collateral
  console.log('open obligation and add collateral...')
  const ethCoinType = `${protocolPublishResult.packageData.packageId}::eth::ETH`;
  const res = await scallopSui.openObligationAndAddCollateral(100, ethCoinType)
  const obligationData = parseOpenObligationResponse(res);
  console.log('open obligation and add collateral done!')

  // register switchboard aggregators
  console.log('register switchboard oracles...')
  const registerRes = await registerSwitchboardOracles(
    protocolPublishResult.packageData.packageId,
    protocolPublishResult.oracleData.switchboard.registryCapId,
    protocolPublishResult.oracleData.switchboard.registryId,
    initMarketResult.switchboardData.ethAggregatorId,
    initMarketResult.switchboardData.usdcAggregatorId,
  );
  console.log(registerRes);
  console.log('register switchboard oracles done!');

  // Write the object ids to a file in json format
  console.log('write object ids to file: object-ids.json')
  writeAsJson({...protocolPublishResult, obligationData, switchboard: initMarketResult.switchboardData, txn: undefined }, 'object-ids.json');
  console.log('write object ids to file done!')
}

setup();
