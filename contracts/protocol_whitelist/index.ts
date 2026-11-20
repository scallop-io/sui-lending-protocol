import * as path from "path"
import { createRequire } from "module";
import { fileURLToPath } from "url";

// ESM does not provide CJS globals; publish-result JSON is loaded by computed path
const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import { networkType } from "sui-elements"
import { ProtocolWhitelistTxBuilder } from "./typescript/tx-builder"
import { publishResult as protocolPublishResult } from "../protocol"

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

export const protocolWhitelistTxBuilder = new ProtocolWhitelistTxBuilder(
  publishResult.packageId,
  protocolPublishResult.publisherIds[0],
  protocolPublishResult.marketId,
);
