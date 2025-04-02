import * as path from "path";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResult } from "contracts/protocol";
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { SuiKit } from "@scallop-io/sui-kit";
import { SuiClient } from "@mysten/sui/client";

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

const upgradeProtocol = async (suiKit: SuiKit) => {
  return packagePublisher.upgradePackageWithDependencies(
    protocolPackagePath,
    oldProtocolPackageId,
    protocolUpgradeCapId,
    protocolDependencies,
    suiKit
  );
}

const createUpgradeProtocolTx = async (client: SuiClient, publisher: string) => {
  const res = await packagePublisher.createUpgradePackageTxWithDependencies(
    protocolPackagePath,
    oldProtocolPackageId,
    protocolUpgradeCapId,
    protocolDependencies,
    client,
    publisher,
  );
  return res.txBytesBase64;
}

createUpgradeProtocolTx(suiKit.client(), MULTI_SIG_ADDRESS).then(console.log).catch(console.error).finally(() => process.exit(0));

// createUpgradeProtocolTx(suiKit.client(), suiKit.currentAddress()).then(console.log).catch(console.error).finally(() => process.exit(0));
