import * as path from "path";
import { packagePublisher, suiKit } from "sui-elements";
import { publishResult } from "contracts/sui_x_oracle/x_oracle";
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { SuiClient } from "@mysten/sui/client";

const xOraclePath = path.join(__dirname, "../contracts/sui_x_oracle/x_oracle");

export const xOracleDependencies = [];

const oldXOraclePackageId = publishResult.packageId;
const xOracleUpgradeCapId = publishResult.upgradeCapId;

const createUpgradeXOracleTx = async (client: SuiClient, publisher: string) => {
  const res = await packagePublisher.createUpgradePackageTxWithDependencies(
    xOraclePath,
    oldXOraclePackageId,
    xOracleUpgradeCapId,
    xOracleDependencies,
    client,
    publisher,
  );

  const resp = await suiKit.client().dryRunTransactionBlock({
    transactionBlock: res.txBytesBase64
  })
  console.log(resp.effects.status);
  return res.txBytesBase64;
}

createUpgradeXOracleTx(suiKit.client(), MULTI_SIG_ADDRESS).then(console.log).catch(console.error).finally(() => process.exit(0));