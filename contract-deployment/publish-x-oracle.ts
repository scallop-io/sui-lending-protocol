import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { packagePublisher } from "sui-elements";

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");
const pythRulePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule");
const switchboardRulePath = path.join(__dirname, "../contracts/sui_x_oracle/switchboard_rule");

const xOraclePackageList: PackageBatch = [
  { packagePath: xOraclePath },
  { packagePath: pythRulePath },
  { packagePath: switchboardRulePath },
];
// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const publishXOracle = async (
  signer: RawSigner
) => {
  return packagePublisher.publishPackageBatch(xOraclePackageList, signer);
}
