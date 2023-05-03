import path from "path";
import { suiKit, networkType } from "./sui-kit-instance";
import { publishProtocol } from "./package-publish/publish-protocol";
import { initMarketForTest } from "./protocol-interaction/init-market";
import { registerSwitchboardOracles } from "./protocol-interaction/register-switchboard-oracles";
import { openObligation } from "./protocol-interaction/open-obligation";
import { supplyBaseAsset } from "./protocol-interaction/supply-base-asset";
import { writeAsJson } from "./write-as-json";

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const protocolPublishResult = await publishProtocol(suiKit.getSigner());

  await delay(3000);

  // init market
  console.log('init market...')
  const initMarketResult = await initMarketForTest(protocolPublishResult);
  console.log('init market result done!')

  // register switchboard aggregators
  console.log('Create and register switchboard oracles...')
  const { testSwitchboardAggregators } = await registerSwitchboardOracles(protocolPublishResult);
  console.log('Create and register switchboard oracles done!');

  // open obligation and add collateral
  console.log('open obligation and add collateral...')
  const obligationData = await openObligation(protocolPublishResult);
  console.log('open obligation and add collateral done!')

  // supply base asset
  console.log('supply base assets...')
  const supplyRes = await supplyBaseAsset(protocolPublishResult);
  console.log('supply base assets done!')

  // Write the object ids to a file in json format
  console.log('write object ids to file: object-ids.json')
  writeAsJson({...protocolPublishResult, obligationData, testSwitchboardAggregators }, `object-ids.${networkType}.json`);
  console.log('write object ids to file done!')
}

setup();
