import * as path from "path"
import { networkType } from "sui-elements"
import { ProtocolWhitelistTxBuilder } from "./typescript/tx-builder"
import { publishResult as protocolPublishResult } from "../protocol"

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

export const protocolWhitelistTxBuilder = new ProtocolWhitelistTxBuilder(
  publishResult.packageId,
  protocolPublishResult.publisherIds[0],
  protocolPublishResult.marketId,
);
