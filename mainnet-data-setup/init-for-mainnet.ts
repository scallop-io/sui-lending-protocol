import { SuiTxBlock } from "@scallop-io/sui-kit";
import { suiKit } from "sui-elements";
import { initXOracle } from "./init-oracle";
import { initCoinDecimalRegistry } from "./init-coin-decimal-registry";
import { initMarket } from "./init-market";
import { addWhitelist } from "./add-whitelist";

export const setupForTestnet = async () => {
  const tx = new SuiTxBlock();
  initXOracle(tx);
  initCoinDecimalRegistry(tx);
  initMarket(tx);
  addWhitelist(tx);
  return suiKit.signAndSendTxn(tx);
}

setupForTestnet().then(console.log).catch(console.error).finally(() => process.exit(0));
