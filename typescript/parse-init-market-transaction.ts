import {
  SuiTransactionBlockResponse,
  getObjectChanges,
  getObjectFields,
  SuiObjectChange,
} from "@mysten/sui.js";
import { suiKit } from "./sui-kit-instance";

export const parseInitMarketTransaction = async (suiResponse: SuiTransactionBlockResponse) => {
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
