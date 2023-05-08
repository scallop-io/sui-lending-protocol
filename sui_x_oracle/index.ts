import * as path from 'path'
import { SuiTxBlock } from '@scallop-io/sui-kit'
import { suiKit, networkType } from '../scripts/sui-kit-instance'
import { publishPackageWithCache, parseMoveToml } from '../scripts/package-publish'
import xOracleIds from "./x_oracle/ids.json"
import pythRuleIds from "./pyth_rule/ids.json"
import switchboardRuleIds from "./switchboard_rule/ids.json"

export const publishXOracle = async () => {
  const pkgPath = path.join(__dirname, './x_oracle');
  return await publishPackageWithCache(pkgPath, suiKit.getSigner(), networkType);
}

export const initXOracle = async () => {
  const { xOracleId, xOracleCapId,packageId } = xOracleIds;
  const pythRulePkgId = pythRuleIds.packageId;
  const switchboardRulePkgId = switchboardRuleIds.packageId;
  const pythRuleType = `${pythRulePkgId}::rule::Rule`;
  const switchboardRuleType = `${switchboardRulePkgId}::rule::Rule`;
  const tx = new SuiTxBlock();
  tx.moveCall(
    `$${packageId}::x_oracle::add_primary_price_update_rule`,
    [xOracleId, xOracleCapId],
    [pythRuleType]
  );
  return suiKit.signAndSendTxn(tx);
}

initXOracle().then(console.log).catch(console.error);
