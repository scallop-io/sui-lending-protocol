import * as path from "path";
import { networkType } from "sui-elements";
import { XOracleTxBuilder } from "./typescript/tx-builder";
export * from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

export const xOracleTxBuilder = new XOracleTxBuilder(publishResult.packageId, publishResult.xOracleId, publishResult.xOracleCapId);
