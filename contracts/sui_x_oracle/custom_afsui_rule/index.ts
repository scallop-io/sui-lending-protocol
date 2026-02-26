import * as path from "path";
import { networkType } from "sui-elements";
import { CustomAfsuiRuleTxBuilder } from "./typescript/tx-builder";

export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const pythOracleData = require(path.join(__dirname, `../pyth_rule/pyth-oracle.${networkType}.json`));
export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const aftermath = require(path.join(__dirname, `./aftermath-ids.json`));
export const customAfsuiRuleTxBuilder = new CustomAfsuiRuleTxBuilder(
  publishResult.packageId,
  publishResult.oracleConfigId,
  publishResult.oracleAdminCapId,
  pythOracleData.wormholeStateId,
  pythOracleData.pythStateId,
  aftermath.stakedSuiVaultId,
  aftermath.safeId,
);

export const customAfsuiRuleStructType = `${publishResult.packageId}::rule::Rule`;
