import * as path from "path"
import { networkType } from "sui-elements"
import { ProtocolTxBuilder } from "./typescript/tx-builder"
export * from "./typescript/publish-result-parser"
export * from "./typescript/tx-builder"


export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const protocolTxBuilder = new ProtocolTxBuilder(
  publishResult.packageId,
  publishResult.adminCapId,
  publishResult.marketId,
  publishResult.versionId,
  publishResult.versionCapId,
  publishResult.obligationAccessStoreId,
  publishResult.borrowReferralWitnessList
);
