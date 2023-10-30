import * as path from "path";
import {JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResult } from "contracts/protocol";
import { MULTI_SIG_ADDRESS } from './multi-sig';

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");
const mathPkgPath = path.join(__dirname, "../contracts/libs/math");
const xPkgPath = path.join(__dirname, "../contracts/libs/x");
const whitelistPkgPath = path.join(__dirname, "../contracts/libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../contracts/libs/coin_decimals_registry");

export const protocolDependencies = [
  { packagePath: xOraclePath },
  { packagePath: mathPkgPath },
  { packagePath: xPkgPath },
  { packagePath: whitelistPkgPath },
  { packagePath: coinDecimalsRegistryPath },
];

const protocolPackagePath = path.join(__dirname, "../contracts/protocol");
const oldProtocolPackageId = publishResult.packageId;
const protocolUpgradeCapId = publishResult.upgradeCapId;

const upgradeProtocol = async (signer: RawSigner) => {
  return packagePublisher.upgradePackageWithDependencies(
    protocolPackagePath,
    oldProtocolPackageId,
    protocolUpgradeCapId,
    protocolDependencies,
    signer
  );
}

const createUpgradeProtocolTx = async (provider: JsonRpcProvider, publisher: string) => {
  return packagePublisher.createUpgradePackageTxWithDependencies(
    protocolPackagePath,
    oldProtocolPackageId,
    protocolUpgradeCapId,
    protocolDependencies,
    provider,
    publisher,
  );
}

createUpgradeProtocolTx(suiKit.provider(), MULTI_SIG_ADDRESS).then(console.log).catch(console.error).finally(() => process.exit(0));

// createUpgradeProtocolTx(suiKit.provider(), suiKit.currentAddress()).then(console.log).catch(console.error).finally(() => process.exit(0));
