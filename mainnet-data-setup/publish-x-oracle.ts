import * as path from "path";;
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResultParser as xOracleParser } from "contracts/sui_x_oracle/x_oracle/typescript/publish-result-parser";
import { publishResultParser as pythRuleParser } from "contracts/sui_x_oracle/pyth_rule/typescript/publish-result-parser";
import { SuiKit } from "@scallop-io/sui-kit";

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");

const wormholePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule/vendors/wormhole");
const pythOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule/vendors/pyth");
const pythRulePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule");


const xOraclePackageList: PackageBatch = [
  { packagePath: xOraclePath, option: { publishResultParser: xOracleParser, enforce: false } },

  { packagePath: wormholePath },
  { packagePath: pythOraclePath },
  { packagePath: pythRulePath, option: { publishResultParser: pythRuleParser, enforce: true } },
];
// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const publishXOracle = async (
  suiKit: SuiKit
) => {
  return packagePublisher.publishPackageBatch(xOraclePackageList, suiKit);
}

publishXOracle(suiKit).then(console.log).catch(console.error).finally(() => process.exit(0));