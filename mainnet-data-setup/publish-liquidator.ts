/**
 * This script is used to publish scallop liquidator to the blockchain.
 * TODO: Move the liquidation contracts to a separate repo when the contracts are stable
 *
 * README:
 * Before running this script, please make sure:
 * 1. Make sure x-oracle is published to the blockchain
 * 2. Make sure the protocol is published to the blockchain
 */

import * as path from "path";
import { RawSigner } from "@mysten/sui.js";
import { PackageBatch } from "@scallop-io/sui-package-kit";
import { packagePublisher, suiKit } from "sui-elements";

/**
 * Oracle related dependencies
 */
const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");
const wormholePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule/vendors/wormhole");
const pythOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule/vendors/pyth");
const pythRulePath = path.join(__dirname, "../contracts/sui_x_oracle/pyth_rule");

/**
 * Protocol related dependencies
 */
const mathPkgPath = path.join(__dirname, "../contracts/libs/math");
const xPkgPath = path.join(__dirname, "../contracts/libs/x");
const whitelistPkgPath = path.join(__dirname, "../contracts/libs/whitelist");
const coinDecimalsRegistryPath = path.join(__dirname, "../contracts/libs/coin_decimals_registry");
const protocolPkgPath = path.join(__dirname, "../contracts/protocol");

/**
 * For liquidation related contracts
 * TODO: Move the liquidation contracts to a separate repo when the contracts are stable
 */
const cetusAdaptorPkgPath = path.join(__dirname, "../contracts/liquidation_related/cetus_adaptor");
const liquidatorPkgPath = path.join(__dirname, "../contracts/liquidation_related/liquidator");

export const protocolPackageList: PackageBatch = [
  // Oracle related dependencies
  { packagePath: xOraclePath },
  { packagePath: wormholePath },
  { packagePath: pythOraclePath },
  { packagePath: pythRulePath },

  // Protocol related dependencies
  { packagePath: mathPkgPath },
  { packagePath: xPkgPath },
  { packagePath: whitelistPkgPath },
  { packagePath: coinDecimalsRegistryPath },
  { packagePath: protocolPkgPath },

  // Liquidation packages
  { packagePath: cetusAdaptorPkgPath, option: { enforce: false } },
  { packagePath: liquidatorPkgPath, option: { enforce: true } },
];
export const publishLiquidator = async (
  signer: RawSigner
) => {
  return packagePublisher.publishPackageBatch(protocolPackageList, signer);
}

publishLiquidator(suiKit.getSigner()).then(console.log).catch(console.error).finally(() => process.exit(0));
