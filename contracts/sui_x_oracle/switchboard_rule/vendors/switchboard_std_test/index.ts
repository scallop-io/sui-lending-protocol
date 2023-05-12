import * as path from "path";
import { SuiTxBlock } from "@scallop-io/sui-kit";
import { networkType } from "sui-elements";
import { SwitchboardTestTxBuilder } from "./typescript/tx-builder";

const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));
export const switchboardTestTxBuilder = new SwitchboardTestTxBuilder(publishResult.packageId);
