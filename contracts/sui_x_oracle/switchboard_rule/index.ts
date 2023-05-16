import * as path from "path";
import { networkType } from "sui-elements";
import { SwitchboardRuleTxBuilder } from "./typescript/tx-builder";
export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

export const switchboardRuleTxBuilder = new SwitchboardRuleTxBuilder(
  publishResult.packageId,
  publishResult.switchboardRegistryId,
  publishResult.switchboardRegistryCapId
);

export const switchboardRuleStructType =  `${publishResult.packageId}::rule::Rule`;

export const switchboardOracleData = require(path.join(__dirname, `./switchboard-oracle.${networkType}.json`))
