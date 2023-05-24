import * as path from "path";
import { networkType } from "sui-elements";
import { SupraRuleTxBuilder } from "./typescript/tx-builder";

const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

export const supraOracleData = require(path.join(__dirname, `./supra-oracle.${networkType}.json`));

export const supraRuleTxBuilder = new SupraRuleTxBuilder(
  publishResult.packageId,
  publishResult.supraRegistryId,
  publishResult.supraRegistryCapId,
  supraOracleData.oracleHolderId,
);

export const supraRuleStructType =  `${publishResult.packageId}::rule::Rule`;
