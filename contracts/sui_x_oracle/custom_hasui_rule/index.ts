import * as path from "path";
import { networkType } from "sui-elements";
import { CustomHasuiRuleTxBuilder } from "./typescript/tx-builder";

export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const pythOracleData = require(path.join(__dirname, `../pyth_rule/pyth-oracle.${networkType}.json`));
export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const haedal = require(path.join(__dirname, `./haedal-ids.json`));
export const customHasuiRuleTxBuilder = new CustomHasuiRuleTxBuilder(
  publishResult.packageId,
  publishResult.oracleConfigId,
  publishResult.oracleAdminCapId,
  pythOracleData.wormholeStateId,
  pythOracleData.pythStateId,
  haedal.hasuiStakingId,
);

export const customHasuiRuleStructType = `${publishResult.packageId}::rule::Rule`;