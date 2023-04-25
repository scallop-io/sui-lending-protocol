import { suiKit } from "./sui-kit-instance";
import { getObjectFields } from "@mysten/sui.js";

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
