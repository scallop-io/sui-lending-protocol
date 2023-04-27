import {
  SuiTransactionBlockResponse,
  getObjectChanges,
  getObjectFields,
  SUI_CLOCK_OBJECT_ID
} from "@mysten/sui.js";
import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit } from './sui-kit-instance';
import type { ProtocolPublishData } from './publish-protocol';

export const initMarketForTest = async (data: ProtocolPublishData) => {

  const target = `${data.packageData.packageId}::app_test::init_market`;
  const suiTxBlock = new SuiTxBlock();
  suiTxBlock.moveCall(
    target,
    [
      data.marketData.marketId,
      data.marketData.adminCapId,
      data.testCoinData.usdc.treasuryId,
      data.marketData.coinDecimalsRegistryId,
      data.testCoinData.usdc.metadataId,
      data.testCoinData.eth.metadataId,
      SUI_CLOCK_OBJECT_ID
    ]);
  suiTxBlock.txBlock.setGasBudget(6 * 10 ** 9);
  const txResponse = await suiKit.signAndSendTxn(suiTxBlock);
  return parseInitMarketTransaction(txResponse);
}

const parseInitMarketTransaction = async (suiResponse: SuiTransactionBlockResponse) => {
  const objectChanges = getObjectChanges(suiResponse);
  const switchboardData = {
    ethAggregatorId: '',
    usdcAggregatorId: '',
  };

  if (objectChanges) {
    for (const change of objectChanges) {
      if (change.type === 'created' && change.objectType.endsWith('aggregator::Aggregator')) {
        const oracle = await parseSwitchboardOracle(change.objectId);
        if (oracle.name === 'ETH/USD') {
          switchboardData.ethAggregatorId = change.objectId;
        } else if (oracle.name === 'USDC/USD') {
          switchboardData.usdcAggregatorId = change.objectId;
        }
      }
    }
  }
  return { switchboardData };
}

export const parseSwitchboardOracle = async (aggregatorId: string) => {
  const aggregator = await suiKit.provider().getObject({
    id: aggregatorId,
    options: {
      showContent: true
    }
  });
  const fields = getObjectFields(aggregator) as {name: Uint8Array};
  return {
    name: Buffer.from(fields.name).toString()
  }
}
