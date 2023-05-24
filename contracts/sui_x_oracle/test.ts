import * as path from "path";
import { networkType } from "sui-elements";

export { switchboardTestTxBuilder } from "./switchboard_rule/vendors/switchboard_std_test"
export const testAggregatorIds = require(path.join(__dirname, `./switchboard_rule/switchboard-oracle.${networkType}.json`))

export const supraOracleData = require(path.join(__dirname, `./supra_rule/supra-oracle.${networkType}.json`));
export const pythOracleData = require(path.join(__dirname, `./pyth_rule/pyth-oracle.${networkType}.json`));
