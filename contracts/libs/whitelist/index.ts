import * as path from "path";
import { networkType } from "sui-elements";
import { WhitelistTxBuilder } from "./typescript/tx-builder";

export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const whitelistTxBuilder = new WhitelistTxBuilder(publishResult.packageId);
