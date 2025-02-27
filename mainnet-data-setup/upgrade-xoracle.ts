import * as path from "path";
import {JsonRpcProvider, RawSigner} from "@mysten/sui.js";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResult } from "contracts/sui_x_oracle/x_oracle";
import { MULTI_SIG_ADDRESS } from './multi-sig';

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");

export const xOracleDependencies = [];

const oldXOraclePackageId = publishResult.packageId;
const xOracleUpgradeCapId = publishResult.upgradeCapId;

const createUpgradeXOracleTx = async (provider: JsonRpcProvider, publisher: string) => {
  const res = await packagePublisher.createUpgradePackageTxWithDependencies(
    xOraclePath,
    oldXOraclePackageId,
    xOracleUpgradeCapId,
    xOracleDependencies,
    provider,
    publisher,
  );
  return res.txBytesBase64;
}

createUpgradeXOracleTx(suiKit.provider(), MULTI_SIG_ADDRESS).then(console.log).catch(console.error).finally(() => process.exit(0));