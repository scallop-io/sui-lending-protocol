import * as path from "path";
import { networkType } from "sui-elements";

export * from "./typescript/publish-result-parser"
import { DecimalsRegistryTxBuilder } from "./typescript/tx-builder"

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const decimalsRegistryTxBuilder = new DecimalsRegistryTxBuilder(publishResult.packageId, publishResult.coinDecimalsRegistryId);
