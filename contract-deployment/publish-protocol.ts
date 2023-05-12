import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { packagePublisher } from "sui-elements";

const mathPkgPath = path.join(__dirname, "../contracts/libs/math");
const xPkgPath = path.join(__dirname, "../contracts/libs/x");
const whitelistPkgPath = path.join(__dirname, "../contracts/libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../contracts/libs/coin_decimals_registry");
const testCoinPkgPath = path.join(__dirname, "../contracts/test_coin");
const protocolPkgPath = path.join(__dirname, "../contracts/protocol");
const protocolQueryPkgPath = path.join(__dirname, "../contracts/query");

export const protocolPackageList: PackageBatch = [
  { packagePath: mathPkgPath },
  { packagePath: xPkgPath },
  { packagePath: whitelistPkgPath },
  { packagePath: coinDecimalsRegistryPath },
  { packagePath: testCoinPkgPath },
  { packagePath: protocolPkgPath },
  { packagePath: protocolQueryPkgPath }
];
export const publishProtocol = async (
  signer: RawSigner
) => {
  return packagePublisher.publishPackageBatch(protocolPackageList, signer);
}
