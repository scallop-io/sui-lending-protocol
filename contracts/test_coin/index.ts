import * as path from "path";
import { networkType } from "sui-elements";
import { TestCoinTxBuilder } from "./typescript/tx-builder";
export * from "./typescript/publish-result-parser";
export * from "./typescript/tx-builder";
export const publishResult = require(path.join(__dirname, `./publish-result.${networkType}.json`));

const treasuryIds = {
  eth: publishResult.eth.treasuryId,
  usdc: publishResult.usdc.treasuryId,
  usdt: publishResult.usdt.treasuryId,
  btc: publishResult.btc.treasuryId,
}
export const testCoinTxBuilder = new TestCoinTxBuilder(publishResult.packageId, treasuryIds);

export const testCoinTypes = {
  btc: `${publishResult.packageId}::btc::BTC`,
  eth: `${publishResult.packageId}::eth::ETH`,
  usdt: `${publishResult.packageId}::usdt::USDT`,
  usdc: `${publishResult.packageId}::usdc::USDC`
}
