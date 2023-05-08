import { suiKit, networkType } from "./sui-kit-instance";
import { publishProtocol } from "./package-publish/publish-protocol";
import { initMarketForTest } from "./protocol-interaction/init-market";
import { handleSwitchboard } from "./protocol-interaction/register-switchboard-oracles";
import { supplyBaseAsset } from "./protocol-interaction/supply-base-asset";

const delay = (ms: number) => {
  console.log(`delay ${ms}ms...`)
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const setup = async () => {
  const protocolPublishResult = await publishProtocol(suiKit.getSigner());

  await delay(3000);

  // init market
  console.log('init market...')
  const initMarketResult = await initMarketForTest();
  console.log('init market result done!')

  // register switchboard aggregators
  console.log('Create and register switchboard oracles...')
  const switchboardRes = await handleSwitchboard(protocolPublishResult);
  if (switchboardRes.ok) {
    console.log('Create and register switchboard oracles done!');
  } else {
    throw new Error('Create and register switchboard oracles failed!');
  }

  // supply base asset
  console.log('supply base assets...')
  const supplyRes = await supplyBaseAsset(protocolPublishResult);
  console.log('supply base assets done!')
}

setup();
