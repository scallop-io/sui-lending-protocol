import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackagePublishResult } from "@scallop-io/sui-package-kit";
import { publishPackageWithCache } from "./package-publish";
import { networkType, suiKit } from "./sui-kit-instance";

const xOraclePath = path.join(__dirname, "../sui_x_oracle/x_oracle");
const pythRulePath = path.join(__dirname, "../sui_x_oracle/pyth_rule");
const switchboardRulePath = path.join(__dirname, "../sui_x_oracle/switchboard_rule");

const xOraclePackageList = [
  { pkgPath: xOraclePath },
  { pkgPath: pythRulePath },
  { pkgPath: switchboardRulePath },
];
// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const publishXOracle = async (
  signer: RawSigner
) => {
  const publishResults: { publishResult: PackagePublishResult, packageName: string }[] = [];
  for (const pkg of xOraclePackageList) {
    const pkgPath = pkg.pkgPath;
    const res = await publishPackageWithCache(pkgPath, signer, networkType)
    res && publishResults.push(res);
  }
  return publishResults;
}

publishXOracle(suiKit.getSigner()).then(console.log).catch(console.error)

