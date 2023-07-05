import { SuiTxBlock } from "@scallop-io/sui-kit";
import { suiKit } from "sui-elements";
import { initXOracleForTest } from "./init-oracle";
import { initCoinDecimalRegistry } from "./init-coin-decimal-registry";
import { initMarketForTest } from "./init-market";
import { whiteListAllowAll } from "./add-whitelist";
import { supplyBaseAsset } from "./supply-base-asset";

export const setupForTestnet = async () => {
  const tx = new SuiTxBlock();
  initXOracleForTest(tx);
  initCoinDecimalRegistry(tx);
  initMarketForTest(tx);
  whiteListAllowAll(tx);
  supplyBaseAsset(tx);
  return suiKit.signAndSendTxn(tx);
}

setupForTestnet().then(console.log).catch(console.error).finally(() => process.exit(0));
