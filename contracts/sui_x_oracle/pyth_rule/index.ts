import * as path from "path";
import { networkType } from "sui-elements";
import { PythRuleTxBuilder } from "./typescript/tx-builder";

export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const pythOracleData = require(path.join(__dirname, `./pyth-oracle.${networkType}.json`));
export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const pythRuleTxBuilder = new PythRuleTxBuilder(
  publishResult.packageId,
  publishResult.pythRegistryId,
  publishResult.pythRegistryCapId,
  pythOracleData.wormholeStateId,
  pythOracleData.pythStateId,
);

export const pythRuleStructType = `${publishResult.packageId}::rule::Rule`;
