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
const protocolWhitelistPkgPath = path.join(__dirname, "../contracts/protocol_whitelist");
const borrowIncentivePkgPath = path.join(__dirname, "../../spool/borrow_incentive");
const borrowIncentiveQueryPkgPath = path.join(__dirname, "../../spool/borrow_incentive_query");

export const protocolPackageList: PackageBatch = [
  { packagePath: xOraclePath },
  { packagePath: mathPkgPath, option: { enforce: false } },
  { packagePath: xPkgPath, option: { enforce: false } },
  { packagePath: whitelistPkgPath, option: { enforce: false } },
  { packagePath: coinDecimalsRegistryPath, option: { publishResultParser: decimalsRegistryParser, enforce: false } },
  { packagePath: protocolPkgPath, option: { publishResultParser: protocolParser, enforce: false } },
  { packagePath: protocolQueryPkgPath, option: { enforce: false } },
  { packagePath: protocolWhitelistPkgPath, option: { enforce: false } },
  { packagePath: borrowIncentivePkgPath, option: { enforce: false } },
  { packagePath: borrowIncentiveQueryPkgPath, option: { enforce: true } },
];
export const publishProtocol = async (
  signer: RawSigner
) => {
  return packagePublisher.publishPackageBatch(protocolPackageList, signer);
}

publishProtocol(suiKit.getSigner()).then(console.log).catch(console.error).finally(() => process.exit(0));
