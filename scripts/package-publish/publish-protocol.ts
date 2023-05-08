import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackagePublishResult } from "@scallop-io/sui-package-kit";
import { publishPackageWithCache } from "./publish-packages";
import { suiKit, networkType } from "../sui-kit-instance";

const mathPkgPath = path.join(__dirname, "../../libs/math");
const xPkgPath = path.join(__dirname, "../../libs/x");
const whitelistPkgPath = path.join(__dirname, "../../libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../../libs/coin_decimals_registry");
const testCoinPkgPath = path.join(__dirname, "../../test_coin");
const protocolPkgPath = path.join(__dirname, "../../protocol");
const protocolQueryPkgPath = path.join(__dirname, "../../query");

const protocolPackageList = [
  { pkgPath: mathPkgPath },
  { pkgPath: xPkgPath },
  { pkgPath: whitelistPkgPath },
  { pkgPath: coinDecimalsRegistryPath },
  { pkgPath: testCoinPkgPath },
  { pkgPath: protocolPkgPath },
  { pkgPath: protocolQueryPkgPath }
];
export const publishProtocol = async (
  signer: RawSigner,
) => {
  return await _publishProtocol(protocolPackageList, signer);
}

// publish packages for the protocol
// the latter package could depend on the former one in the list, so the order matters
export const _publishProtocol = async (
  packagePathList: { pkgPath: string, placeholderNames?: string[], enableCache?: boolean }[],
  signer: RawSigner
) => {
  const publishResults: { publishResult: PackagePublishResult, packageName: string }[] = [];
  for (const pkg of packagePathList) {
    const pkgPath = pkg.pkgPath;
    const res = await publishPackageWithCache(pkgPath, signer, networkType)
    res && publishResults.push(res);
  }
}

publishProtocol(suiKit.getSigner()).then(console.log).catch(console.error);
