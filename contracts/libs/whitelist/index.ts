import * as path from "path";
import { createRequire } from "module";
import { fileURLToPath } from "url";

// ESM does not provide CJS globals; publish-result JSON is loaded by computed path
const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
import { networkType } from "sui-elements";
import { WhitelistTxBuilder } from "./typescript/tx-builder";

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const whitelistTxBuilder = new WhitelistTxBuilder(publishResult.packageId);
