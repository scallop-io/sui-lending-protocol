import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackagePublishResult } from "@scallop-io/sui-package-kit";
import { publishPackageWithCache } from "./publish-packages";
import { networkType, suiKit } from "../sui-elements";

const mathPkgPath = path.join(__dirname, "../contracts/libs/math");
const xPkgPath = path.join(__dirname, "../contracts/libs/x");
const whitelistPkgPath = path.join(__dirname, "../contracts/libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../contracts/libs/coin_decimals_registry");
const testCoinPkgPath = path.join(__dirname, "../contracts/test_coin");
const protocolPkgPath = path.join(__dirname, "../contracts/protocol");
const protocolQueryPkgPath = path.join(__dirname, "../contracts/query");

const protocolPackageList = [
  { pkgPath: mathPkgPath },
  { pkgPath: xPkgPath },
  { pkgPath: whitelistPkgPath },
  { pkgPath: coinDecimalsRegistryPath },
  { pkgPath: testCoinPkgPath },
  { pkgPath: protocolPkgPath },
  { pkgPath: protocolQueryPkgPath }
];
// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const publishProtocol = async (
  signer: RawSigner
) => {
  const publishResults: { publishResult: PackagePublishResult, packageName: string }[] = [];
  for (const pkg of protocolPackageList) {
    const pkgPath = pkg.pkgPath;
    const res = await publishPackageWithCache(pkgPath, signer, networkType)
    res && publishResults.push(res);
  }
  return publishResults;
}

publishProtocol(suiKit.getSigner()).then(console.log).catch(console.error)

