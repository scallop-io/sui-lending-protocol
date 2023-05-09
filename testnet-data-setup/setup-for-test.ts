import { SuiTxBlock } from "@scallop-io/sui-kit";
import { suiKit } from "../sui-elements";
import { initMarketForTest } from "./init-market";
import { initCoinDecimalRegistry } from './init-coin-decimal-registry';
import { initXOracleForTest } from "./init-oracle";
import { supplyBaseAsset } from "./supply-base-asset";

export const setupForTestnet = async () => {
  const tx = new SuiTxBlock();
  initMarketForTest(tx);
  initCoinDecimalRegistry(tx);
  initXOracleForTest(tx);
  supplyBaseAsset(tx);
  tx.txBlock.setGasBudget(10 ** 9);
  const res = await suiKit.signAndSendTxn(tx);
  console.log(res);
}

setupForTestnet();
