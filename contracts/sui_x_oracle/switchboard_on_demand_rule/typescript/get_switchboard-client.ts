import { SuiClient } from "@mysten/sui/client";
import { Aggregator, SwitchboardClient } from "@switchboard-xyz/sui-sdk";
import { SuiTxBlock, SUI_CLOCK_OBJECT_ID } from "@scallop-io/sui-kit";

interface UpdateParams {
  address: string;
  queue: string;
  successValue: string;
  isNegative: boolean;
  timestamp: number;
  oracleId: string;
  signature: number[];
  queueFee: number;
}

interface Response {
  updateData: UpdateParams[];
  responses: any[];
  failures: string[];
  switchboardAddress: string;
}

/**
 * Create a SwitchboardClient using the SuiClient configured with your favorite RPC on testnet or mainnet
 * @param switchboardAggregatorId - ID of the Switchboard Aggregator
 * @param rpc - RPC URL to connect to the Sui network
 * @returns void
 * @example
 * ```typescript
 * const switchboardAggregatorId = "0xSomeFeedId";
 * const sb = await addSwitchboardUpdateInTx(tx: txBlock, switchboardAggregatorId);
 * ```
 */
export const addSwitchboardUpdateInTx = async (
  tx: SuiTxBlock,
  switchboardAggregatorId: string,
  rpc: string
) => {
  const sb = new SwitchboardClient(new SuiClient({ url: rpc }));
  const aggregator = new Aggregator(sb, switchboardAggregatorId);

  // Fetch update parameters from the aggregator
  const response: Response = await aggregator.fetchUpdate();

  if (response.updateData.length === 0) {
    throw new Error("No update data available for this aggregator.");
  }

  // Split SUI from gas fees
  let i = 0;
  let updateFees = tx.splitSUIFromGas(
    response.updateData.map((u) => u.queueFee)
  );

  // Iterate over updateData and create move calls for each update
  for (const update of response.updateData) {
    const {
      address,
      queue,
      successValue,
      isNegative,
      timestamp,
      oracleId,
      signature,
    } = update;

    tx.moveCall(
      `${response.switchboardAddress}::aggregator_submit_result_action::run`,
      [
        address, // Aggregator
        queue, // Queue
        successValue, // Value (u128)
        isNegative, // neg (bool)
        timestamp, // timestamp_seconds (u64)
        oracleId, // Oracle
        signature, // Signature (vector<u8>)
        SUI_CLOCK_OBJECT_ID, // Clock (replace with actual clock object path)
        updateFees[i], // Coin Fee
      ],
      ["0x2::sui::SUI"]
    );

    i += 1;
  }
};
