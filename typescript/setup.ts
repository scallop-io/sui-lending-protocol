import path from "path";
import { suiKit } from "./sui-kit-instance";
import { initMarketForTest } from "./init-market";
import { publishProtocol } from "./publish-protocol";
import { registerSwitchboardOracles } from "./register-switchboard-oracles";
import { openObligation } from "./open-obligation";
import { writeAsJson } from "./write-as-json";

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const packagePath = path.join(__dirname, '../query');
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

  // open obligation and add collateral
  console.log('open obligation and add collateral...')
  const obligationData = await openObligation(
    protocolPublishResult.packageData.packageId,
    protocolPublishResult.marketData.marketId
  );
  console.log('open obligation and add collateral done!')

  // register switchboard aggregators
  console.log('register switchboard oracles...')
  const registerRes = await registerSwitchboardOracles(
    protocolPublishResult.packageData.packageId,
    protocolPublishResult.oracleData.switchboard.registryCapId,
    protocolPublishResult.oracleData.switchboard.registryId,
    initMarketResult.switchboardData.ethAggregatorId,
    initMarketResult.switchboardData.usdcAggregatorId,
    initMarketResult.switchboardData.usdtAggregatorId,
    initMarketResult.switchboardData.btcAggregatorId,
    initMarketResult.switchboardData.suiAggregatorId,
  );
  console.log(registerRes);
  console.log('register switchboard oracles done!');

  // Write the object ids to a file in json format
  console.log('write object ids to file: object-ids.json')
  writeAsJson({...protocolPublishResult, obligationData, switchboard: initMarketResult.switchboardData, txn: undefined }, 'object-ids.json');
  console.log('write object ids to file done!')
}

setup();
