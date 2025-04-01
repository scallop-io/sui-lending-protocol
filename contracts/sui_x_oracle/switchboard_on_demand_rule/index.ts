import * as path from "path";
import { networkType } from "sui-elements";
import { SwitchboardOnDemandRuleTxBuilder } from "./typescript/tx-builder";
export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const publishResult = require(path.join(
  __dirname,
  `./publish-result.${networkType}.json`
));

export const switchboardOnDemandRuleTxBuilder =
  new SwitchboardOnDemandRuleTxBuilder(
    publishResult.packageId,
    publishResult.switchboardRegistryId,
    publishResult.switchboardRegistryCapId
  );

export const switchboardOnDemandRuleStructType = `${publishResult.packageId}::rule::Rule`;

export const switchboardOnDemandOracleData = require(path.join(
  __dirname,
  `./switchboard-oracle.${networkType}.json`
));
