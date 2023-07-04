import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResultParser as decimalsRegistryParser } from "contracts/libs/coin_decimals_registry/typescript/publish-result-parser";
import { publishResultParser as protocolParser } from "contracts/protocol/typescript/publish-result-parser";

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");
const mathPkgPath = path.join(__dirname, "../contracts/libs/math");
const xPkgPath = path.join(__dirname, "../contracts/libs/x");
const whitelistPkgPath = path.join(__dirname, "../contracts/libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../contracts/libs/coin_decimals_registry");
const protocolPkgPath = path.join(__dirname, "../contracts/protocol");
const protocolQueryPkgPath = path.join(__dirname, "../contracts/query");

export const protocolPackageList: PackageBatch = [
  { packagePath: xOraclePath },
  { packagePath: mathPkgPath, option: { enforce: true } },
  { packagePath: xPkgPath, option: { enforce: true } },
  { packagePath: whitelistPkgPath, option: { enforce: true } },
  { packagePath: coinDecimalsRegistryPath, option: { publishResultParser: decimalsRegistryParser } },
  { packagePath: protocolPkgPath, option: { publishResultParser: protocolParser, enforce: true } },
  { packagePath: protocolQueryPkgPath, option: { enforce: true } }
];
export const publishProtocol = async (
  signer: RawSigner
) => {
  return packagePublisher.publishPackageBatch(protocolPackageList, signer);
}

publishProtocol(suiKit.getSigner()).then(console.log).catch(console.error).finally(() => process.exit(0));
